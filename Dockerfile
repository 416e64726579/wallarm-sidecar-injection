FROM golang:1.14-alpine as builder

RUN apk add --no-cache git=2.24.3-r0
ENV IMAGE_NAME=wallarm-sidecar-injector

WORKDIR /go/src/${IMAGE_NAME}
COPY go.mod .
COPY go.sum .
RUN go mod download

COPY cmd .
RUN GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o ${IMAGE_NAME} .

FROM alpine:3.16.7

LABEL sidecar="wallarm"

ENV SIDECAR_INJECTOR=/usr/local/bin/wallarm-sidecar-injector \
    USER_UID=1001 \
    USER_NAME=wallarm-sidecar-injector \
    IMAGE_NAME=wallarm-sidecar-injector

COPY --from=builder /go/src/${IMAGE_NAME}/${IMAGE_NAME} ${SIDECAR_INJECTOR}
RUN echo "hosts: files dns" > /etc/nsswitch.conf
WORKDIR /usr/local/bin/
RUN apk add --no-cache ca-certificates=20191127-r1

USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/wallarm-sidecar-injector"]