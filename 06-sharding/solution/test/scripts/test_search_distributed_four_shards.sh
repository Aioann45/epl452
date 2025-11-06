```shell name=06-sharding/solution/test/scripts/test_search_distributed_four_shards.sh url=https://github.com/Aioann45/epl452/blob/3a121701e39e2e81c40234b678795ae64ad67659/06-sharding/solution/test/scripts/test_search_distributed_four_shards.sh
#!/bin/bash

set -e

# Determine the absolute path of the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set the project root as two directories above the script location
PROJECT_HOME="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Define paths to executables and relevant data files
INDEXSERVER_BIN="$PROJECT_HOME/bin/indexserver"
WEBSERVER_BIN="$PROJECT_HOME/bin/webserver"
INDEX_FILE_0="$PROJECT_HOME/test/data/invertedindex-small.txt"
INDEX_FILE_1="$PROJECT_HOME/test/data/invertedindex-medium.txt"
INDEX_FILE_2="$PROJECT_HOME/test/data/invertedindex-medium-0.txt"
INDEX_FILE_3="$PROJECT_HOME/test/data/invertedindex-medium-1.txt"
HTML_PATH="$PROJECT_HOME/web/static/index.html"

# Define a list of 100 pre-selected queries used for benchmarking
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

# Utility function to return the current timestamp in milliseconds (GNU date required)
now_ms() {
  date +%s%3N
}

echo "Project home: $PROJECT_HOME"
echo "Using indexes:"
echo "  Shard 0: $INDEX_FILE_0"
echo "  Shard 1: $INDEX_FILE_1"
echo "  Shard 2: $INDEX_FILE_2"
echo "  Shard 3: $INDEX_FILE_3"
echo

# Launch 4 indexserver instances, each hosting a separate shard
echo "Starting indexserver shard 0 on 127.0.0.1:9090..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9090" -index_files="$INDEX_FILE_0" &
PID0=$!

echo "Starting indexserver shard 1 on 127.0.0.1:9091..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9091" -index_files="$INDEX_FILE_1" &
PID1=$!

echo "Starting indexserver shard 2 on 127.0.0.1:9092..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9092" -index_files="$INDEX_FILE_2" &
PID2=$!

echo "Starting indexserver shard 3 on 127.0.0.1:9093..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9093" -index_files="$INDEX_FILE_3" &
PID3=$!

# Pause briefly to give the index servers time to start up
sleep 2

# Start the webserver configured to communicate with all four shards
echo "Starting webserver on 0.0.0.0:8080..."
SHARDS="127.0.0.1:9090,127.0.0.1:9091,127.0.0.1:9092,127.0.0.1:9093"
"$WEBSERVER_BIN" -addr="0.0.0.0:8080" -shards="$SHARDS" -htmlPath="$HTML_PATH" -topk=100 &
WEB_PID=$!

# Allow additional time for the webserver to become available
sleep 2

echo
echo "Running query benchmark (4 shards)..."

total_time_ms=0
num_queries=${#QUERIES[@]}

batch_start_ms=$(now_ms)

# Loop through all queries, record and report latency for each, and accumulate total time
for q in "${QUERIES[@]}"; do
  start_ms=$(now_ms)

  # Submit search query (response is suppressed)
  curl -sG --data-urlencode "q=$q" "http://localhost:8080/api/search" >/dev/null

  end_ms=$(now_ms)
  elapsed_ms=$(( end_ms - start_ms ))
  total_time_ms=$(( total_time_ms + elapsed_ms ))

  echo "Query: '$q' took ${elapsed_ms} ms"
done

batch_end_ms=$(now_ms)
batch_elapsed_ms=$(( batch_end_ms - batch_start_ms ))

echo
echo "===== Results (4 shards) ====="
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
echo "Shard 0:"
ps -p "$PID0" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID0 not found"
echo
echo "Shard 1:"
ps -p "$PID1" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID1 not found"
echo
echo "Shard 2:"
ps -p "$PID2" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID2 not found"
echo
echo "Shard 3:"
ps -p "$PID3" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID3 not found"
echo
echo "Webserver:"
ps -p "$WEB_PID" -o pid,cmd,%cpu,%mem,etime || echo "Web PID $WEB_PID not found"

# Gracefully stop all background processes started by this script
echo
echo "Cleaning up..."
kill "$PID0" "$PID1" "$PID2" "$PID3" "$WEB_PID" || true
wait "$PID0" "$PID1" "$PID2" "$PID3" "$WEB_PID" 2>/dev/null || true

echo "Test complete (4 shards)."

```
