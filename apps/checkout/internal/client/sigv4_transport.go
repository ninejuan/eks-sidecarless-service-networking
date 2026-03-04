package client

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
)

const (
	vpcLatticeServiceName = "vpc-lattice-svcs"
	emptyPayloadHash      = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)

type SigV4Transport struct {
	inner       http.RoundTripper
	region      string
	credentials aws.CredentialsProvider
	signer      *v4.Signer
}

func NewSigV4Transport(ctx context.Context, region string, inner http.RoundTripper) (*SigV4Transport, error) {
	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(region))
	if err != nil {
		return nil, err
	}

	_, err = awsCfg.Credentials.Retrieve(ctx)
	if err != nil {
		return nil, err
	}

	if inner == nil {
		inner = http.DefaultTransport
	}

	return &SigV4Transport{
		inner:       inner,
		region:      region,
		credentials: awsCfg.Credentials,
		signer:      v4.NewSigner(),
	}, nil
}

func (t *SigV4Transport) RoundTrip(request *http.Request) (*http.Response, error) {
	req := request.Clone(request.Context())

	body, payloadHash, err := readBodyAndHash(request)
	if err != nil {
		return nil, err
	}

	if body != nil {
		req.Body = io.NopCloser(bytes.NewReader(body))
		req.ContentLength = int64(len(body))
		req.GetBody = func() (io.ReadCloser, error) {
			return io.NopCloser(bytes.NewReader(body)), nil
		}
	}

	credentials, err := t.credentials.Retrieve(req.Context())
	if err != nil {
		return nil, err
	}

	if err := t.signer.SignHTTP(req.Context(), credentials, req, payloadHash, vpcLatticeServiceName, t.region, time.Now()); err != nil {
		return nil, err
	}

	return t.inner.RoundTrip(req)
}

func readBodyAndHash(request *http.Request) ([]byte, string, error) {
	if request.Body == nil {
		return nil, emptyPayloadHash, nil
	}

	body, err := io.ReadAll(request.Body)
	if err != nil {
		return nil, "", err
	}

	if err := request.Body.Close(); err != nil {
		return nil, "", err
	}

	if len(body) == 0 {
		return []byte{}, emptyPayloadHash, nil
	}

	hash := sha256.Sum256(body)
	return body, hex.EncodeToString(hash[:]), nil
}
