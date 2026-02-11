package repository

import (
	"context"
	"errors"
	"strconv"

	awscfg "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"

	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/config"
	"github.com/ninejuan/eks-sidecarless-service-networking/apps/inventory/internal/domain"
)

type DynamoRepository struct {
	client *dynamodb.Client
	table  string
}

func NewDynamoRepository(cfg config.Config) (*DynamoRepository, error) {
	awsConfig, err := awscfg.LoadDefaultConfig(context.Background(), awscfg.WithRegion(cfg.AWSRegion))
	if err != nil {
		return nil, err
	}

	return &DynamoRepository{
		client: dynamodb.NewFromConfig(awsConfig),
		table:  cfg.DynamoDBTable,
	}, nil
}

func (r *DynamoRepository) Ping(ctx context.Context) error {
	_, err := r.client.DescribeTable(ctx, &dynamodb.DescribeTableInput{TableName: &r.table})
	return err
}

func (r *DynamoRepository) GetStock(ctx context.Context, sku string) (domain.StockItem, error) {
	output, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: &r.table,
		Key: map[string]types.AttributeValue{
			"sku": &types.AttributeValueMemberS{Value: sku},
		},
		ConsistentRead: boolPtr(true),
	})
	if err != nil {
		return domain.StockItem{}, err
	}

	if len(output.Item) == 0 {
		return domain.StockItem{SKU: sku, AvailableQuantity: 0}, nil
	}

	quantityAttr, ok := output.Item["available_quantity"].(*types.AttributeValueMemberN)
	if !ok {
		return domain.StockItem{}, errors.New("available_quantity attribute is missing")
	}

	parsedQty, err := strconv.Atoi(quantityAttr.Value)
	if err != nil {
		return domain.StockItem{}, err
	}

	return domain.StockItem{SKU: sku, AvailableQuantity: parsedQty}, nil
}

func (r *DynamoRepository) Reserve(ctx context.Context, req domain.ReserveRequest) error {
	_, err := r.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: &r.table,
		Key: map[string]types.AttributeValue{
			"sku": &types.AttributeValueMemberS{Value: req.SKU},
		},
		UpdateExpression:          strPtr("SET available_quantity = available_quantity - :qty"),
		ConditionExpression:       strPtr("available_quantity >= :qty"),
		ExpressionAttributeValues: map[string]types.AttributeValue{":qty": &types.AttributeValueMemberN{Value: strconv.Itoa(req.Quantity)}},
		ReturnValues:              types.ReturnValueUpdatedNew,
	})
	if err == nil {
		return nil
	}

	var condErr *types.ConditionalCheckFailedException
	if errors.As(err, &condErr) {
		return domain.ErrInsufficientStock
	}

	return err
}

func boolPtr(value bool) *bool {
	return &value
}

func strPtr(value string) *string {
	return &value
}
