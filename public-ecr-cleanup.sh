#!/bin/bash

set -eu

if ! command -v aws >/dev/null; then
    echo "missing aws command" >&2
    exit 1
fi

REGISTRY_ID=${REGISTRY_ID}
REPOSITORY_NAME=${REPOSITORY_NAME}
BATCH_DELETE_SIZE=${BATCH_DELETE_SIZE:-50}


function batch_delete {
    while read -r batch; do
        if [ -z "${batch}" ]; then
            break
        fi

        echo "Deleting ${batch}"
        aws ecr-public batch-delete-image \
            --registry-id "${REGISTRY_ID}" \
            --repository-name "${REPOSITORY_NAME}" \
            --image-ids ${batch}

    done < <(xargs -L ${BATCH_DELETE_SIZE} <<<"$1")
}

IMAGE_DIGESTS=$(aws ecr-public describe-images \
    --no-paginate \
    --registry-id "${REGISTRY_ID}" \
    --repository-name "${REPOSITORY_NAME}" \
    --query 'imageDetails[?!imageTags && (contains(imageManifestMediaType, `manifest.list.v2`) || contains(imageManifestMediaType, `image.index.v1`))].{imageDigest: join(`=`, [`imageDigest`, imageDigest])}' \
    --output text)

batch_delete "${IMAGE_DIGESTS}"

IMAGE_DIGESTS=$(aws ecr-public describe-images \
    --no-paginate \
    --registry-id "${REGISTRY_ID}" \
    --repository-name "${REPOSITORY_NAME}" \
    --query 'imageDetails[?!imageTags].{imageDigest: join(`=`, [`imageDigest`, imageDigest])}' \
    --output text)

batch_delete "${IMAGE_DIGESTS}"
