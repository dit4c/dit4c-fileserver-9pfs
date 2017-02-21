.DEFAULT_GOAL=all
.PHONY=clean all deploy

NAME=dit4c-fileserver-9pfs
BASE_DIR=.
BUILD_DIR=${BASE_DIR}/build
OUT_DIR=${BASE_DIR}/dist
TARGET_IMAGE=${OUT_DIR}/${NAME}.linux.amd64.aci

MKDIR_P=mkdir -p
GPG=gpg2

ALPINE_DOCKER_IMAGE=alpine:3.5
ALPINE_ACI=${BUILD_DIR}/library-alpine-3.5.aci

ACBUILD=${BUILD_DIR}/acbuild
ACBUILD_VERSION=0.4.0
ACBUILD_URL=https://github.com/containers/build/releases/download/v${ACBUILD_VERSION}/acbuild-v${ACBUILD_VERSION}.tar.gz

DOCKER2ACI=${BUILD_DIR}/docker2aci
DOCKER2ACI_VERSION=0.15.0
DOCKER2ACI_URL=https://github.com/appc/docker2aci/releases/download/v${DOCKER2ACI_VERSION}/docker2aci-v${DOCKER2ACI_VERSION}.tar.gz

CONFD=${BUILD_DIR}/confd
CONFD_VERSION=0.11.0
CONFD_URL=https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-linux-amd64

ETC_FILES=$(shell find ${BASE_DIR}/etc)
U9FS_BINARY=u9fs/u9fs

${BUILD_DIR}:
	${MKDIR_P} ${BUILD_DIR}

${OUT_DIR}:
	${MKDIR_P} ${OUT_DIR}

clean:
	rm -rf ${BUILD_DIR} ${OUT_DIR}

${ACBUILD}: | ${BUILD_DIR}
	curl -sL ${ACBUILD_URL} | tar xz --touch --strip-components=1 -C ${BUILD_DIR}

${DOCKER2ACI}: | ${BUILD_DIR}
	curl -sL ${DOCKER2ACI_URL} | tar xz --touch --strip-components=1 -C ${BUILD_DIR}

${CONFD}: | ${BUILD_DIR}
	curl -sL -o ${CONFD} ${CONFD_URL}
	chmod +x ${CONFD}

${ALPINE_ACI}: ${DOCKER2ACI}
	cd ${BUILD_DIR} && ../${DOCKER2ACI} docker://${ALPINE_DOCKER_IMAGE}

${TARGET_IMAGE}: ${ACBUILD} ${ALPINE_ACI} ${CONFD} ${ETC_FILES} ${U9FS_BINARY} install.sh start.sh | ${OUT_DIR}
	sudo rm -rf .acbuild
	sudo ${ACBUILD} --debug begin ${ALPINE_ACI}
	sudo ${ACBUILD} --debug copy ${CONFD} /usr/local/bin/confd
	sudo ${ACBUILD} --debug copy ${U9FS_BINARY} /usr/local/bin/u9fs
	sudo ${ACBUILD} --debug copy-to-dir install.sh start.sh /
	sudo ${ACBUILD} --debug copy-to-dir etc/* /etc
	sudo sh -c 'PATH=${shell echo $$PATH}:${BUILD_DIR} ${ACBUILD} --debug run --engine chroot -- sh -c "./install.sh && rm -f install.sh"'
	sudo ${ACBUILD} --debug set-exec -- /start.sh
	sudo ${ACBUILD} --debug set-name ${NAME}
	sudo ${ACBUILD} --debug environment add DIT4C_PORTAL 'https://dit4c.net'
	sudo ${ACBUILD} --debug mount add data /data
	sudo ${ACBUILD} --debug port add ssh tcp 22
	sudo ${ACBUILD} --debug write --overwrite $@
	sudo ${ACBUILD} --debug end
	sudo chown $(shell id -u):$(shell id -g) $@

${TARGET_IMAGE}.asc: ${TARGET_IMAGE} signing.key
	$(eval TMP_PUBLIC_KEYRING := $(shell mktemp -p ./build))
	$(eval TMP_SECRET_KEYRING := $(shell mktemp -p ./build))
	$(eval GPG_FLAGS := --batch --no-default-keyring --keyring $(TMP_PUBLIC_KEYRING) --secret-keyring $(TMP_SECRET_KEYRING) )
	$(GPG) $(GPG_FLAGS) --import signing.key
	rm -f $@
	$(GPG) $(GPG_FLAGS) --armour --detach-sign $<
	rm $(TMP_PUBLIC_KEYRING) $(TMP_SECRET_KEYRING)

all: ${TARGET_IMAGE}

deploy: ${TARGET_IMAGE} ${TARGET_IMAGE}.asc
