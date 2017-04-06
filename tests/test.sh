# read tokens from local env.sh 
if [ "$1" == "build" ]; then
	docker build -t sematext/sematext-agent-docker:test ..
fi

source ./env.sh
# read nginx port from docker-compose file
export PORT=$(cat ./docker-compose.yml | grep :80 | awk '{print $2}' | tr : ' ' | awk '{print $1}')
docker-compose up -d 
function log_count_test () 
{
	# generate random test ID
	export TEST_ID=TEST$(jot  -r 1 1000 900000)$(jot  -r 1 1000 900000)
	echo testID = $TEST_ID
	export LOG_NO=5
	docker run --rm -t --net=host jstarcher/siege -r $LOG_NO -c 50 http://127.0.0.1:$PORT/${TEST_ID} | grep Transactions
	sleep 40 
	echo '{"query" : { "query_string" : {"query": "path:'$TEST_ID' AND status_code:404" }}}' > query.txt
	echo curl -XPOST "https://logsene-receiver.sematext.com/LOGSENE_TOKEN/_count?q=path:?$TEST_ID" -d @query.txt
	export count=$(curl -XPOST "logsene-receiver.sematext.com/$LOGSENE_TOKEN/_count?q=path:?$TEST_ID" -d @query.txt | jq '.count')
	echo "log count in Logsene: $count"
	# each nginx request generates 2 logs
	export generated_logs=$(expr $LOG_NO \* 50 \* 2)
	echo $generated_logs
	export result=$(expr $count  - $generated_logs)
	if [ $result == 0 ]; then
		echo SUCCESS $count $result
		return 0
	else
		echo failed: $count $result
		return -1
	fi 	
}
log_count_test