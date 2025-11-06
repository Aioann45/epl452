```shell name=06-sharding/solution/test/scripts/test_search_distributed_one_shard.sh url=https://github.com/Aioann45/epl452/blob/50cc60134ebfcbbca72b3b9d760da72eee7507d4/06-sharding/solution/test/scripts/test_search_distributed_one_shard.sh
#!/bin/bash

set -e

# Determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Assume the project root is two directories above the script location
PROJECT_HOME="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Define paths for binaries and relevant data files
INDEXSERVER_BIN="$PROJECT_HOME/bin/indexserver"
WEBSERVER_BIN="$PROJECT_HOME/bin/webserver"
INDEX_FILE="$PROJECT_HOME/test/data/invertedindex-medium.txt"
HTML_PATH="$PROJECT_HOME/web/static/index.html"

# Array of 100 example queries—these are consistently used for all performance tests
QUERIES=(
"adventure"
"mystery"
"friendship"
"journey"
"courage"
"love"
"revenge"
"justice"
"freedom"
"survival"
"sacrifice"
"transformation"
"wisdom"
"honor"
"loyalty"
"innocence"
"grief"
"loss"
"redemption"
"power"
"deception"
"discovery"
"escape"
"tradition"
"ambition"
"truth"
"memory"
"isolation"
"unity"
"resilience"

"adventure mystery"
"friendship courage"
"love revenge"
"justice freedom"
"survival sacrifice"
"transformation wisdom"
"honor loyalty"
"innocence grief"
"loss redemption"
"power deception"
"discovery escape"
"tradition ambition"
"truth memory"
"isolation unity"
"resilience conflict"
"healing fate"
"rebellion leadership"
"compassion nostalgia"
"temptation exile"
"secrecy guilt"
"chaos peace"
"fear endurance"
"danger betrayal"
"hope destiny"
"legacy courage"
"love justice"
"freedom truth"
"power survival"
"friendship loyalty"
"journey wisdom"

"adventure mystery courage"
"love revenge justice"
"freedom survival sacrifice"
"transformation wisdom honor"
"loyalty innocence grief"
"loss redemption power"
"deception discovery escape"
"tradition ambition truth"
"memory isolation unity"
"resilience conflict healing"
"fate rebellion leadership"
"compassion nostalgia temptation"
"exile secrecy guilt"
"chaos peace fear"
"endurance danger betrayal"
"hope destiny legacy"
"courage love friendship"
"justice freedom survival"
"sacrifice transformation wisdom"
"honor loyalty unity"
"grief loss redemption"
"power deception truth"
"discovery escape adventure"
"tradition ambition memory"
"isolation resilience compassion"
"fate healing courage"
"rebellion leadership honor"
"nostalgia temptation exile"
"secrecy guilt chaos"
"peace fear endurance"

"adventure courage friendship unity"
"love revenge justice freedom"
"survival sacrifice honor loyalty"
"wisdom transformation grief loss"
"redemption power deception truth"
"discovery escape ambition tradition"
"memory isolation resilience compassion"
"fate rebellion leadership courage"
"healing nostalgia temptation exile"
"secrecy guilt chaos peace"
"fear endurance danger betrayal"
"hope destiny legacy wisdom"
"courage friendship loyalty honor"
"freedom justice truth power"
"love grief redemption loss"
"transformation survival resilience unity"
"compassion healing peace hope"
"rebellion fate destiny leadership"
"memory nostalgia innocence tradition"
"escape discovery adventure courage"
"sacrifice honor loyalty faith"
"resilience endurance strength courage"
"unity compassion peace hope"
"power deception chaos control"
"grief loss redemption healing"
"truth justice freedom survival"
"fear courage endurance resilience"
"tradition ambition legacy destiny"
"innocence wisdom compassion unity"
"love courage redemption hope"
)

# Helper function to get the current time in milliseconds (relies on GNU date)
now_ms() {
  date +%s%3N
}

echo "Project home: $PROJECT_HOME"
echo "Using index: $INDEX_FILE"
echo

# Launch the indexserver (shard) in the background and record its PID
echo "Starting indexserver shard on 127.0.0.1:9090..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9090" -index_files="$INDEX_FILE" &
INDEX_PID=$!

# Pause briefly to allow indexserver to initialize
sleep 2

# Start the webserver process in the background and record its PID
echo "Starting webserver on 0.0.0.0:8080..."
"$WEBSERVER_BIN" -addr="0.0.0.0:8080" -shards="127.0.0.1:9090" -htmlPath="$HTML_PATH" -topk=10 &
WEB_PID=$!

# Pause to make sure the webserver is ready
sleep 2

echo
echo "Running query benchmark (1 shard)..."

total_time_ms=0
num_queries=${#QUERIES[@]}

batch_start_ms=$(now_ms)

# Loop through each query and submit it to the webserver, measuring latency
for q in "${QUERIES[@]}"; do
  start_ms=$(now_ms)

  # Issue the search query (output is suppressed)
  curl -sG --data-urlencode "q=$q" "http://localhost:8080/api/search" >/dev/null

  end_ms=$(now_ms)
  elapsed_ms=$(( end_ms - start_ms ))
  total_time_ms=$(( total_time_ms + elapsed_ms ))

  echo "Query: '$q' took ${elapsed_ms} ms"
done

batch_end_ms=$(now_ms)
batch_elapsed_ms=$(( batch_end_ms - batch_start_ms ))

echo
echo "===== Results (1 shard) ====="
echo "Total queries:     $num_queries"
echo "Total time (ms):   $batch_elapsed_ms"
avg_latency_ms=$(( total_time_ms / num_queries ))
echo "Avg latency (ms):  $avg_latency_ms"

if [ "$batch_elapsed_ms" -gt 0 ]; then
  qps=$(( num_queries * 1000 / batch_elapsed_ms ))
  echo "Throughput (QPS):  $qps"
else
  echo "Throughput (QPS):  N/A (total time too small)"
fi

echo
echo "Resource usage snapshot before cleanup:"
echo "Indexserver:"
ps -p "$INDEX_PID" -o pid,cmd,%cpu,%mem,etime || echo "Index PID $INDEX_PID not found"
echo
echo "Webserver:"
ps -p "$WEB_PID" -o pid,cmd,%cpu,%mem,etime || echo "Web PID $WEB_PID not found"

# Terminate both background servers gracefully
echo
echo "Cleaning up..."
kill "$INDEX_PID" "$WEB_PID" || true
wait "$INDEX_PID" "$WEB_PID" 2>/dev/null || true

echo "Done (1 shard)."
```
