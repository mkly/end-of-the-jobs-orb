setup () {
  source `pwd`/../scripts/source.sh
}

@test "Fetch Workflow Ids" {
  data='{
  "next_page_token" : null,
  "items" : [ {
    "pipeline_id" : "a9100686-b466-4263-a86d-5e6749e3f5ea",
    "id" : "7sdo3490-f10c-4321-8572-9fe5dde2a95c",
    "name" : "wf",
    "project_slug" : "gh/example/example",
    "status" : "success",
    "started_by" : "edddesg-9e45-4888-901f-946ef3a9sdfe",
    "pipeline_number" : 683,
    "created_at" : "2020-07-22T18:39:15Z",
    "stopped_at" : "2020-07-22T18:40:37Z"
  } ]
}
'
  mock_curl () {
    echo $data
  }

  [[ $(_check_for_the_end__fetch_workflow_ids mock_curl 123 987) == '7sdo3490-f10c-4321-8572-9fe5dde2a95c' ]]
}

@test "Fetch Job Statuses" {

  data='{
  "next_page_token": null,
  "items": [
    {
      "dependencies": [],
      "job_number": 1085,
      "id": "6b1xx6e6-ff33-45dc-b08b-62fdd2aa780c",
      "started_at": "2020-07-22T18:39:23Z",
      "name": "prehold",
      "project_slug": "gh/example/example",
      "status": "success",
      "type": "build",
      "stopped_at": "2020-07-22T18:39:30Z"
    },
    {
      "dependencies": [
        "bf1b82f2-f3f1-43b3-a7bf-2a08ee5ec910"
      ],
      "id": "6b1xx6e6-ff33-45dc-b08b-62fdd2aa780c",
      "started_at": null,
      "name": "hold",
      "approved_by" : "edddesg-9e45-4888-901f-946ef3a9sdfe",
      "project_slug": "gh/example/example",
      "status": "success",
      "type": "approval",
      "approval_request_id": "e4c1eb9a-84b1-4877-9a84-efcxxdewe909"
    },
    {
      "dependencies": [
        "e4c1eb9a-84b1-4877-9a84-efc8xsdfewf"
      ],
      "job_number": 1086,
      "id": "6b1xx6e6-ff33-45dc-b08b-62fdd2aa780c",
      "started_at": "2020-07-22T18:40:14Z",
      "name": "cpu",
      "project_slug": "gh/example/example",
      "status": "running",
      "type": "build",
      "stopped_at": "2020-07-22T18:40:37Z"
    }
  ]
}
'
  mock_curl () {
    echo $data
  }

  job_number=1086

  _check_for_the_end__fetch_job_statuses mock_curl 123 $job_number 987
  #[[ $(_check_for_the_end__fetch_job_statuses mock_curl 123 $job_number 987) == 'success success success' ]]
}

@test "Check Job Statuses" {
  comm='echo testing'
  data='success success success'

  [[ $(_check_for_the_end__check_job_statuses "$data" "$comm") == "testing" ]]

}

@test "Check Job Statuses On Hold" {
  comm='echo testing'
  data='success on_hold success'

  [[ $(_check_for_the_end__check_job_statuses "$data" "$comm") == "Jobs still running" ]]
}
