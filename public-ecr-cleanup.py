import boto3
import os

ecr_public = boto3.client('ecr-public')

REGISTRY_ID = os.environ['REGISTRY_ID']
BATCH_DELETE_SIZE = int(os.environ.get('BATCH_DELETE_SIZE', 50))


def batch_delete(repository_name, image_digests):
    errors = []

    for i in range(0, len(image_digests), BATCH_DELETE_SIZE):
        batch = image_digests[i:i + BATCH_DELETE_SIZE]
        print(f"[{repository_name}] Deleting {len(batch)} images...")
        response = ecr_public.batch_delete_image(
            registryId=REGISTRY_ID,
            repositoryName=repository_name,
            imageIds=[{'imageDigest': digest} for digest in batch]
        )
        failures = response.get("failures", [])
        if failures:
            for fail in failures:
                failure_code = fail.get("failureCode")
                failure_digest = fail["imageId"]["imageDigest"]
                failure_reason = fail.get("failureReason", "")
                if failure_code == "ImageReferencedByManifestList":
                    print(f"Skipped image {failure_digest} — referenced by a manifest list")
                else:
                    print(f"Failed to delete {failure_digest}: {failure_code} - {failure_reason}")
                    errors.append({
                        "repository": repository_name,
                        "digest": failure_digest,
                        "code": failure_code,
                        "reason": failure_reason
                    })
    return errors

def get_untagged_manifest_list_images(repository_name):
    paginator = ecr_public.get_paginator('describe_images')
    untagged = []

    for page in paginator.paginate(
        registryId=REGISTRY_ID,
        repositoryName=repository_name
    ):
        for image in page.get('imageDetails', []):
            if not image.get('imageTags'):
                media_type = image.get('imageManifestMediaType', '')
                if 'manifest.list.v2' in media_type or 'image.index.v1' in media_type:
                    untagged.append(image['imageDigest'])
    return untagged


def get_all_untagged_images(repository_name):
    paginator = ecr_public.get_paginator('describe_images')
    untagged = []

    for page in paginator.paginate(
        registryId=REGISTRY_ID,
        repositoryName=repository_name
    ):
        for image in page.get('imageDetails', []):
            if not image.get('imageTags'):
                untagged.append(image['imageDigest'])
    return untagged


def lambda_handler(event, context):
    deleted_total = 0
    all_errors = []

    # Get all public repositories
    paginator = ecr_public.get_paginator('describe_repositories')
    for page in paginator.paginate(registryId=REGISTRY_ID):
        for repo in page.get('repositories', []):
            repo_name = repo['repositoryName']
            print(f"Processing repository: {repo_name}")

            manifest_list_digests = get_untagged_manifest_list_images(repo_name)
            errors_1 = batch_delete(repo_name, manifest_list_digests)

            remaining_untagged = get_all_untagged_images(repo_name)
            errors_2 = batch_delete(repo_name, remaining_untagged)

            deleted_total += len(manifest_list_digests) + len(remaining_untagged)

            all_errors.extend(errors_1 + errors_2)

    if all_errors:
        return {
            "statusCode": 500,
            "body": f"Deleted {deleted_total} images but encountered errors: {all_errors}"
        }


    return {
        "statusCode": 200,
        "body": f"Deleted {deleted_total} images across all repositories"
    }
