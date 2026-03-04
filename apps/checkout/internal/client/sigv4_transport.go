package client

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
)

const (
	vpcLatticeServiceName = "vpc-lattice-svcs"
	unsignedPayload       = "UNSIGNED-PAYLOAD"
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

	// VPC Lattice does not support payload signing.
	// Must use UNSIGNED-PAYLOAD for x-amz-content-sha256 header.
	req.Header.Set("x-amz-content-sha256", unsignedPayload)

	// Read and re-attach body for the inner transport
	if request.Body != nil {
		body, err := io.ReadAll(request.Body)
		if err != nil {
			return nil, err
		}
		_ = request.Body.Close()
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

	if err := t.signer.SignHTTP(req.Context(), credentials, req, unsignedPayload, vpcLatticeServiceName, t.region, time.Now()); err != nil {
		return nil, err
	}

	return t.inner.RoundTrip(req)
}
