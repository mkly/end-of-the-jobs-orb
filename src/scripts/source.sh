_check_for_the_end__fetch_workflow_ids () {
  local curl=$1
  local pipeline_id=$2
  local token=$3

  workflows_resp=$(eval $curl -s "https://circleci.com/api/v2/pipeline/${pipeline_id}/workflow?circle-token=${token}" -H "Accept:application/json")

  if [[ $workflows_resp == "" ]] ; then
    echo "Unable to download workflows"
    return 1
  fi
  workflow_ids=$(echo $workflows_resp | jq -r '.items[] | .id')
  next_page_token=$(echo $workflows_resp | jq -r '.next_page_token')

  if [[ $workflow_ids == "" ]] ; then
    echo "No workflows found in pipeline"
    return 1
  fi

  while [[ $next_page_token != "null" && $next_page_token != "" ]] ; do
    workflows_resp=$(eval $curl -s "https://circleci.com/api/v2/pipeline/${pipeline_id}/workflow?circle-token=${token}" -H "Accept:application/json")
    workflow_ids="${workflow_ids} $(echo $workflows_resp | jq -r '.items[] | .id')"
    next_page_token=$(echo $workflows_resp | jq -r '.next_page_token')
  done

  echo $workflow_ids
}

_check_for_the_end__fetch_job_statuses () {
  local curl=$1
  local workflow_ids=$2
  local self_job_num=$3
  local token=$4

  for workflow_id in $workflow_ids ; do
    jobs_resp=$(eval $curl -s "https://circleci.com/api/v2/workflow/${workflow_id}/job?circle-token=${token}" -H "Accept:application/json")

    # Filter out the active job and the other running jobs
    job_statuses=$(echo $jobs_resp | jq -r ".items[] | (select((has(\"job_number\") | not) or (.job_number | contains(${self_job_num}) | not))) | .status")
    next_page_token=$(echo $jobs_resp | jq -r '.next_page_token')

    while [[ $next_page_token != "null" && $next_page_token != "" ]] ; do
      job_statuses="${job_status} $(echo $jobs_resp | jq -r '.items[] | .job_status')"
      next_page_token=$(echo $jobs_resp | jq -r '.next_page_token')
    done
  done

  if [[ $job_statuses == "" ]] ; then
    echo "No jobs found in workflow"
    return 1;
  fi

  echo $job_statuses
}


_check_for_the_end__check_job_statuses () {
  local job_statuses=$1

  for job_status in $job_statuses ; do
    if [[ $job_status != "success" && $job_status != "failed" && $job_status != "canceled" && $job_status != "cancelled" && $job_status != "blocked" && $job_status != "queued" ]] ; then
      echo "Jobs still running"
      return 0
    fi
  done

  echo $job_statuses
}

_check_for_the_end__get_workflow_name () {
    local curl=$1
    local workflow_id=$2

    workflow_resp=$(eval $curl -v "https://circleci.com/api/v2/workflow/${workflow_id}?circle-token=${token}" -H "Accept:application/json")
    workflow_name=$(echo $workflow_resp | jq -r '.name')

    echo $workflow_name
}

check_for_the_end_of_the_workflow () {
  local token=$1
  local workflow_id=$2
  local self_job_num=$3
  local pipeline_num=$4
  local vcs=$5
  local org=$6
  local repo=$7

  echo -n "Waiting for all jobs to finish: ."
  result="Jobs still running"
  while [[ $result == "Jobs still running" ]] ; do
    sleep 5
    echo -n "."
    job_statuses=$(_check_for_the_end__fetch_job_statuses curl $workflow_id $self_job_num $token)
    result=$(_check_for_the_end__check_job_statuses "$job_statuses")
  done

  local workflow_name=$(_check_for_the_end__get_workflow_name curl $workflow_id)

  local color=""
  local message=""
  if [[ $job_statuses == *"failed"* ]] ; then
    color="#cc0000"
    message="Workflow: ${workflow_name} failed."
  elif [[ $job_statuses == *"canceled"* ]] ; then
    color="#666666"
    message="Workflow: ${workflow_name} canceled."
  else
    color="#33cc33"
    message="Workflow: ${workflow_name} passed."
  fi

  local workflow_url="https://app.circleci.com/pipelines/${vcs}/${org}/${repo}/${pipeline_num}/workflows/${workflow_id}"

  echo "export EOTJ_JOB_MESSAGE=\"$message\"" >> $BASH_ENV
  echo "export EOTJ_COLOR=\"$color\"" >> $BASH_ENV
  echo "export EOTJ_WORKFLOW_URL=\"$workflow_url\"" >> $BASH_ENV
}

if [ "$CIRCLE_JOB" = "end-of-the-jobs/execute_on_end_workflow" ] ; then
    if [[ -z "${EOTJ_CIRCLE_TOKEN}" ]]; then
      echo "Environment variable \$EOTJ_CIRCLE_TOKEN is not set"
      echo "This must be set to a CircleCI token to access the API"
    fi

    check_for_the_end_of_the_workflow \
      "${EOTJ_CIRCLE_TOKEN}" \
      "${CIRCLE_WORKFLOW_ID}" \
      "${CIRCLE_BUILD_NUM}" \
      "${EOTJ_PIPELINE_NUM}" \
      "${EOTJ_PIPELINE_PROJECT_TYPE}" \
      "${CIRCLE_PROJECT_USERNAME}" \
      "${CIRCLE_PROJECT_REPONAME}"
fi
