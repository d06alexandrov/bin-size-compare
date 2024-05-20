#!/bin/bash

set -e

NEW_DIR=new
OLD_DIR=old

COMPARE_FILE=compare.md

# Function to create or update comment in PR
update_pr_message () {
    PR_NUMBER=$1
    MSG_FILE=$2

    gh pr comment ${PR_NUMBER} --edit-last --body-file "${MSG_FILE}" || gh pr comment ${PR_NUMBER} --body-file "${MSG_FILE}"

    return $?
}

# Set directory as safe
git config --global --add safe.directory $PWD

# Find open PR for current branch and base sha
PR_INFO=$(gh api -XGET repos/{owner}/{repo}/pulls -F head="{owner}:${GITHUB_REF_NAME}" -F state="open" --jq "[(.[].number | tostring), .[].base.sha] | join(\" \")")

if [ -z "$PR_INFO" ];
then
    echo "There are no open PRs, skip"
else
    gh run download ${GITHUB_RUN_ID} -p ${INPUT_ARTIFACT_NAME} -D ${NEW_DIR}

    read -r PR_NUMBER BASE_SHA <<< "$PR_INFO"

    BASE_RUN_ID=$(gh api -XGET repos/{owner}/{repo}/actions/runs -F head_sha="$BASE_SHA" -F status="success" --jq ".workflow_runs[].id" || true)

    if [ -z "${BASE_RUN_ID}" ]
    then
        echo "No suitable base run"

        echo "Size information for artifact $(ls ${NEW_DIR}) (sha: ${GITHUB_SHA}) " > "${COMPARE_FILE}"

        python3 compare.py -n "${NEW_DIR}/*/${INPUT_BINARY_NAME}" -o "${COMPARE_FILE}"
    else
        gh run download ${BASE_RUN_ID} -p ${INPUT_ARTIFACT_NAME} -D ${OLD_DIR}

        echo "Size information for artifact $(ls ${NEW_DIR}) (sha: ${GITHUB_SHA}) in comparison to $(ls ${OLD_DIR}) (sha: ${BASE_SHA})" > "${COMPARE_FILE}"

        python3 compare.py -n "${NEW_DIR}/*/${INPUT_BINARY_NAME}" \
                           -p "${OLD_DIR}/*/${INPUT_BINARY_NAME}" -o "${COMPARE_FILE}"
    fi

    update_pr_message $PR_NUMBER "${COMPARE_FILE}"
fi
