_check_for_the_end__fetch_workflow_ids () {
  local curl=$1
  local pipeline_id=$2
  local token=$3

  workflows_resp=$(eval $curl -s "https://circleci.com/api/v2/pipeline/${pipeline_id}/workflow?circle-token=${token}")

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
    workflows_resp=$(eval $curl -s "https://circleci.com/api/v2/pipeline/${pipeline_id}/workflow?circle-token=${token}")
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
    jobs_resp=$(eval $curl -s "https://circleci.com/api/v2/workflow/${workflow_id}/job?circle-token=${token}")

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
  local execute=$2

  for job_status in $job_statuses ; do
    if [[ $job_status != "success" && $job_status != "failed" && $job_status != "canceled" && $job_status != "cancelled" ]] ; then
      echo "Jobs still running"
      return 0;
    fi
  done

  eval $execute
}

check_for_the_end_of_the_pipeline () {
  local token=$1
  local pipeline_id=$2
  local self_job_num=$3
  local execute=$4

  result="Jobs still running"
  while [[ $result == "Jobs still running" ]] ; do
    sleep 5
    workflow_ids=$(_check_for_the_end__fetch_workflow_ids curl $pipeline_id $token)
    job_statuses=$(_check_for_the_end__fetch_job_statuses curl $workflow_id $self_job_num $token) 
    result=$(_check_for_the_end__check_job_statuses $job_statuses $execute)
  done

  echo "Pipeline finished"
  echo $result
}

check_for_the_end_of_the_workflow () {
  local token=$1
  local workflow_id=$2
  local self_job_num=$3
  local execute=$4

  result="Jobs still running"
  while [[ $result == "Jobs still running" ]] ; do
    sleep 5
    job_statuses=$(_check_for_the_end__fetch_job_statuses curl $workflow_id $self_job_num $token)
    result=$(_check_for_the_end__check_job_statuses $job_statuses $execute)
  done

  echo "Worflow Finished"
  echo $result
}
