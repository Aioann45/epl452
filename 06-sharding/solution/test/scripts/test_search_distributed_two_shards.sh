#!/bin/bash

set -e

# Determine the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Assume the project root is two levels above the script directory
PROJECT_HOME="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Define paths to necessary binaries and data files
INDEXSERVER_BIN="$PROJECT_HOME/bin/indexserver"
WEBSERVER_BIN="$PROJECT_HOME/bin/webserver"
INDEX_FILE_0="$PROJECT_HOME/test/data/invertedindex-medium-0.txt"
INDEX_FILE_1="$PROJECT_HOME/test/data/invertedindex-medium-1.txt"
HTML_PATH="$PROJECT_HOME/web/static/index.html"

# List of 100 search queries for benchmark testing
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

# Helper function to get the current time in milliseconds (uses GNU date)
now_ms() {
  date +%s%3N
}

echo "Project home: $PROJECT_HOME"
echo "Using indexes:"
echo "  Shard 0: $INDEX_FILE_0"
echo "  Shard 1: $INDEX_FILE_1"
echo

# Launch the first indexserver shard in the background
echo "Starting indexserver shard 0 on 127.0.0.1:9090..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9090" -index_files="$INDEX_FILE_0" &
PID1=$!

# Launch the second indexserver shard in the background
echo "Starting indexserver shard 1 on 127.0.0.1:9091..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9091" -index_files="$INDEX_FILE_1" &
PID2=$!

# Give the indexservers a moment to start up
sleep 2

# Launch the webserver, connecting it to both indexserver shards
echo "Starting webserver on 0.0.0.0:8080..."
"$WEBSERVER_BIN" -addr="0.0.0.0:8080" -shards="127.0.0.1:9090,127.0.0.1:9091" -htmlPath="$HTML_PATH" -topk=100 &
PID3=$!

# Give the webserver time to initialize
sleep 2

echo
echo "Running query benchmark (2 shards)..."

total_time_ms=0
num_queries=${#QUERIES[@]}

batch_start_ms=$(now_ms)

# Loop through all queries and measure the latency for each
for q in "${QUERIES[@]}"; do
  start_ms=$(now_ms)

  # Make the search request (silent mode, discard output)
  curl -sG --data-urlencode "q=$q" "http://localhost:8080/api/search" >/dev/null

  end_ms=$(now_ms)
  elapsed_ms=$(( end_ms - start_ms ))
  total_time_ms=$(( total_time_ms + elapsed_ms ))

  echo "Query: '$q' took ${elapsed_ms} ms"
done

batch_end_ms=$(now_ms)
batch_elapsed_ms=$(( batch_end_ms - batch_start_ms ))

echo
echo "===== Results (2 shards) ====="
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
ps -p "$PID1" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID1 not found"
echo
echo "Shard 1:"
ps -p "$PID2" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID2 not found"
echo
echo "Webserver:"
ps -p "$PID3" -o pid,cmd,%cpu,%mem,etime || echo "PID $PID3 not found"

# Clean up all background processes
echo
echo "Cleaning up..."
kill "$PID1" "$PID2" "$PID3" || true
wait "$PID1" "$PID2" "$PID3" 2>/dev/null || true

echo "Test complete (2 shards)."
