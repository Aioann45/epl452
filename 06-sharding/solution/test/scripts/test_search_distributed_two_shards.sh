#!/bin/bash

set -e

# Resolve the directory this script is in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Assume project root is two levels up from script location
PROJECT_HOME="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Paths to binaries and data
INDEXSERVER_BIN="$PROJECT_HOME/bin/indexserver"
WEBSERVER_BIN="$PROJECT_HOME/bin/webserver"
INDEX_FILE_0="$PROJECT_HOME/test/data/invertedindex-medium-0.txt"
INDEX_FILE_1="$PROJECT_HOME/test/data/invertedindex-medium-1.txt"
HTML_PATH="$PROJECT_HOME/web/static/index.html"

# 100 consistent queries used by all benchmarks
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
  "conflict"
  "healing"
  "fate"
  "rebellion"
  "leadership"
  "compassion"
  "nostalgia"
  "temptation"
  "exile"
  "secrecy"
  "adventure mystery"
  "adventure truth"
  "mystery revenge"
  "mystery conflict"
  "friendship wisdom"
  "friendship nostalgia"
  "journey power"
  "journey endurance"
  "courage isolation"
  "love wisdom"
  "love nostalgia"
  "revenge escape"
  "justice survival"
  "justice rebellion"
  "freedom discovery"
  "survival sacrifice"
  "sacrifice unity"
  "transformation resilience"
  "wisdom exile"
  "honor fate"
  "loyalty resilience"
  "innocence compassion"
  "grief rebellion"
  "loss conflict"
  "redemption unity"
  "power isolation"
  "deception isolation"
  "discovery unity"
  "escape conflict"
  "tradition rebellion"
  "ambition temptation"
  "truth fear"
  "isolation healing"
  "unity secrecy"
  "conflict leadership"
  "fate rebellion"
  "leadership nostalgia"
  "compassion memory"
  "nostalgia freedom"
  "secrecy guilt"
  "adventure mystery friendship"
  "adventure escape secrecy"
  "mystery innocence deception"
  "friendship sacrifice tradition"
  "journey justice loss"
  "courage love discovery"
  "courage rebellion peace"
  "love healing compassion"
  "revenge healing chaos"
  "justice compassion fear"
  "survival transformation redemption"
  "sacrifice innocence peace"
  "transformation tradition resilience"
  "wisdom secrecy fear"
  "loyalty ambition healing"
  "grief deception fear"
  "redemption escape conflict"
  "deception resilience temptation"
  "tradition conflict exile"
  "isolation compassion fear"
)

# Function to get current time in milliseconds (requires GNU date)
now_ms() {
  date +%s%3N
}

echo "Project home: $PROJECT_HOME"
echo "Using indexes:"
echo "  Shard 0: $INDEX_FILE_0"
echo "  Shard 1: $INDEX_FILE_1"
echo

# Start indexserver shards in background
echo "Starting indexserver shard 0 on 127.0.0.1:9090..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9090" -index_files="$INDEX_FILE_0" &
PID1=$!

echo "Starting indexserver shard 1 on 127.0.0.1:9091..."
"$INDEXSERVER_BIN" -rpc_addr="127.0.0.1:9091" -index_files="$INDEX_FILE_1" &
PID2=$!

# Wait a moment to ensure index servers are up
sleep 2

# Start webserver with both shards
echo "Starting webserver on 0.0.0.0:8080..."
"$WEBSERVER_BIN" -addr="0.0.0.0:8080" -shards="127.0.0.1:9090,127.0.0.1:9091" -htmlPath="$HTML_PATH" -topk=100 &
PID3=$!

# Wait a moment to ensure webserver is up
sleep 2

echo
echo "Running query benchmark (2 shards)..."

total_time_ms=0
num_queries=${#QUERIES[@]}

batch_start_ms=$(now_ms)

for q in "${QUERIES[@]}"; do
  start_ms=$(now_ms)

  # Execute query (quiet output, discard body)
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

# Cleanup
echo
echo "Cleaning up..."
kill "$PID1" "$PID2" "$PID3" || true
wait "$PID1" "$PID2" "$PID3" 2>/dev/null || true

echo "Test complete (2 shards)."
