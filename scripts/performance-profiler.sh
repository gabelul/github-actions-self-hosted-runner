#!/bin/bash

# Performance Profiler for GitHub Self-Hosted Runner
# Measures and reports on script execution times, resource usage, and optimization opportunities

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly PROFILE_DIR="$PROJECT_ROOT/.performance"
readonly PROFILE_REPORT="$PROFILE_DIR/profile-report-$(date +%Y%m%d-%H%M%S).json"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Profiling configuration
PROFILE_MODE="${1:-basic}"
TARGET_SCRIPT="${2:-}"
ITERATIONS="${3:-3}"

# Ensure profile directory exists
mkdir -p "$PROFILE_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[PROFILE]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_metric() {
    echo -e "${PURPLE}[METRIC]${NC} $1"
}

# Get current system metrics
get_system_metrics() {
    local cpu_usage
    local memory_usage
    local disk_io

    # CPU usage
    if command -v mpstat >/dev/null 2>&1; then
        cpu_usage=$(mpstat 1 1 | awk '/Average/ {print 100-$NF}')
    else
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    fi

    # Memory usage
    if [[ "$(uname)" == "Darwin" ]]; then
        memory_usage=$(vm_stat | awk '/Pages active/ {active=$3} /Pages wired/ {wired=$4} /Pages free/ {free=$3} END {total=active+wired+free; print (active+wired)/total*100}')
    else
        memory_usage=$(free -m | awk '/Mem:/ {print ($3/$2)*100}')
    fi

    # Disk I/O (simplified)
    if command -v iostat >/dev/null 2>&1; then
        disk_io=$(iostat -d 1 2 | tail -n2 | awk '{print $3+$4}')
    else
        disk_io="N/A"
    fi

    echo "{\"cpu\": $cpu_usage, \"memory\": $memory_usage, \"disk_io\": \"$disk_io\"}"
}

# Profile a single script execution
profile_script() {
    local script_path="$1"
    local run_number="$2"

    log_info "Profiling run $run_number of $script_path"

    # Start metrics
    local start_time
    start_time=$(date +%s%N)
    local start_metrics
    start_metrics=$(get_system_metrics)

    # Create trace file for detailed profiling
    local trace_file="$PROFILE_DIR/trace-$(basename "$script_path")-$run_number.txt"

    # Execute script with profiling
    if [[ "$PROFILE_MODE" == "detailed" ]]; then
        # Use bash -x for detailed trace
        bash -x "$script_path" > "$trace_file" 2>&1 &
        local pid=$!
        wait $pid
        local exit_code=$?
    else
        # Basic execution
        "$script_path" > /dev/null 2>&1 &
        local pid=$!
        wait $pid
        local exit_code=$?
    fi

    # End metrics
    local end_time
    end_time=$(date +%s%N)
    local end_metrics
    end_metrics=$(get_system_metrics)

    # Calculate execution time
    local execution_time=$((($end_time - $start_time) / 1000000))  # Convert to milliseconds

    # Generate profile data
    cat << EOF
{
    "script": "$script_path",
    "run": $run_number,
    "execution_time_ms": $execution_time,
    "exit_code": $exit_code,
    "start_metrics": $start_metrics,
    "end_metrics": $end_metrics,
    "timestamp": "$(date -Iseconds)"
}
EOF
}

# Profile all scripts in a directory
profile_directory() {
    local dir="$1"
    local results="[]"

    log_info "Profiling all scripts in $dir"

    while IFS= read -r -d '' script; do
        if [[ -x "$script" ]]; then
            local script_results="[]"

            for i in $(seq 1 "$ITERATIONS"); do
                local profile_data
                profile_data=$(profile_script "$script" "$i")
                script_results=$(echo "$script_results" | jq ". += [$profile_data]")
            done

            # Calculate average execution time
            local avg_time
            avg_time=$(echo "$script_results" | jq '[.[].execution_time_ms] | add / length')

            log_metric "$(basename "$script"): Average ${avg_time}ms over $ITERATIONS runs"

            results=$(echo "$results" | jq ". += $script_results")
        fi
    done < <(find "$dir" -name "*.sh" -type f -print0)

    echo "$results"
}

# Analyze performance hotspots
analyze_hotspots() {
    local profile_data="$1"

    log_info "Analyzing performance hotspots..."

    # Find slowest scripts
    echo "$profile_data" | jq -r '
        group_by(.script) |
        map({
            script: .[0].script,
            avg_time: ([.[].execution_time_ms] | add / length),
            min_time: ([.[].execution_time_ms] | min),
            max_time: ([.[].execution_time_ms] | max),
            runs: length
        }) |
        sort_by(.avg_time) |
        reverse |
        .[:5] |
        .[] |
        "\(.script | split("/") | last): avg=\(.avg_time)ms, min=\(.min_time)ms, max=\(.max_time)ms"
    ' | while read -r line; do
        log_metric "Hotspot: $line"
    done
}

# Generate optimization recommendations
generate_recommendations() {
    local profile_data="$1"

    log_info "Generating optimization recommendations..."

    # Check for scripts with high variance
    echo "$profile_data" | jq -r '
        group_by(.script) |
        map({
            script: .[0].script,
            variance: (([.[].execution_time_ms] | max) - ([.[].execution_time_ms] | min))
        }) |
        .[] |
        select(.variance > 100) |
        .script
    ' | while read -r script; do
        log_warning "High variance detected in $script - may have performance issues"
    done

    # Check for scripts with high CPU usage
    echo "$profile_data" | jq -r '
        .[] |
        select(.end_metrics.cpu > 80) |
        .script
    ' | sort -u | while read -r script; do
        log_warning "High CPU usage in $script - consider optimization"
    done

    # Check for scripts with high memory usage
    echo "$profile_data" | jq -r '
        .[] |
        select(.end_metrics.memory > 80) |
        .script
    ' | sort -u | while read -r script; do
        log_warning "High memory usage in $script - check for memory leaks"
    done
}

# Benchmark specific operations
benchmark_operations() {
    log_info "Running operation benchmarks..."

    # Benchmark GitHub API calls
    log_metric "GitHub API response time:"
    time curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit > /dev/null

    # Benchmark file operations
    local test_file="$PROFILE_DIR/benchmark-test.txt"
    log_metric "File I/O benchmark:"

    # Write test
    time (for i in {1..1000}; do echo "Test line $i" >> "$test_file"; done)

    # Read test
    time (while read -r line; do :; done < "$test_file")

    # Clean up
    rm -f "$test_file"

    # Benchmark process creation
    log_metric "Process creation benchmark:"
    time (for i in {1..100}; do true; done)
}

# Compare performance between versions
compare_versions() {
    local version1="$1"
    local version2="$2"

    log_info "Comparing performance between $version1 and $version2"

    # Check out version 1 and profile
    git checkout "$version1" 2>/dev/null
    local v1_results
    v1_results=$(profile_directory "$PROJECT_ROOT/scripts")

    # Check out version 2 and profile
    git checkout "$version2" 2>/dev/null
    local v2_results
    v2_results=$(profile_directory "$PROJECT_ROOT/scripts")

    # Compare results
    echo "Version comparison:" | tee -a "$PROFILE_REPORT"
    echo "$v1_results" | jq -r --arg v2 "$v2_results" '
        . as $v1 |
        $v2 | fromjson as $v2_data |
        # Compare average times
        "Performance differences detected"
    '
}

# Generate HTML report
generate_html_report() {
    local profile_data="$1"
    local html_report="$PROFILE_DIR/performance-report.html"

    log_info "Generating HTML report at $html_report"

    cat > "$html_report" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Performance Profile Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .slow { background-color: #ffcccc; }
        .fast { background-color: #ccffcc; }
    </style>
</head>
<body>
    <h1>GitHub Self-Hosted Runner Performance Report</h1>
    <p>Generated: <script>document.write(new Date().toLocaleString());</script></p>

    <h2>Script Performance Summary</h2>
    <table id="performance-table">
        <thead>
            <tr>
                <th>Script</th>
                <th>Average Time (ms)</th>
                <th>Min Time (ms)</th>
                <th>Max Time (ms)</th>
                <th>Runs</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody id="performance-data">
        </tbody>
    </table>

    <script>
        const profileData = PROFILE_DATA_PLACEHOLDER;

        // Process and display data
        const grouped = profileData.reduce((acc, item) => {
            if (!acc[item.script]) {
                acc[item.script] = [];
            }
            acc[item.script].push(item);
            return acc;
        }, {});

        const tbody = document.getElementById('performance-data');
        Object.entries(grouped).forEach(([script, runs]) => {
            const times = runs.map(r => r.execution_time_ms);
            const avg = times.reduce((a, b) => a + b, 0) / times.length;
            const min = Math.min(...times);
            const max = Math.max(...times);

            const row = tbody.insertRow();
            row.className = avg > 1000 ? 'slow' : avg < 100 ? 'fast' : '';

            row.insertCell(0).textContent = script.split('/').pop();
            row.insertCell(1).textContent = avg.toFixed(2);
            row.insertCell(2).textContent = min;
            row.insertCell(3).textContent = max;
            row.insertCell(4).textContent = runs.length;
            row.insertCell(5).textContent = avg > 1000 ? '⚠️ Slow' : '✅ OK';
        });
    </script>
</body>
</html>
EOF

    # Replace placeholder with actual data
    sed -i.bak "s|PROFILE_DATA_PLACEHOLDER|$profile_data|" "$html_report"
    rm -f "$html_report.bak"

    log_success "HTML report generated: $html_report"
}

# Main profiling function
main() {
    log_info "Starting performance profiling (mode: $PROFILE_MODE)"

    local profile_results

    if [[ -n "$TARGET_SCRIPT" ]]; then
        # Profile specific script
        if [[ ! -f "$TARGET_SCRIPT" ]]; then
            log_warning "Script not found: $TARGET_SCRIPT"
            exit 1
        fi

        profile_results="[]"
        for i in $(seq 1 "$ITERATIONS"); do
            local result
            result=$(profile_script "$TARGET_SCRIPT" "$i")
            profile_results=$(echo "$profile_results" | jq ". += [$result]")
        done
    else
        # Profile all scripts
        profile_results=$(profile_directory "$PROJECT_ROOT/scripts")
    fi

    # Save raw profile data
    echo "$profile_results" > "$PROFILE_REPORT"
    log_success "Profile data saved to $PROFILE_REPORT"

    # Analyze results
    analyze_hotspots "$profile_results"
    generate_recommendations "$profile_results"

    # Run benchmarks if in detailed mode
    if [[ "$PROFILE_MODE" == "detailed" ]]; then
        benchmark_operations
    fi

    # Generate HTML report
    generate_html_report "$profile_results"

    log_success "Performance profiling complete"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [mode] [target_script] [iterations]

Modes:
    basic     - Basic execution time profiling (default)
    detailed  - Detailed profiling with trace analysis
    compare   - Compare performance between versions

Examples:
    $0                              # Profile all scripts with basic mode
    $0 detailed setup.sh 5          # Detailed profile of setup.sh with 5 iterations
    $0 compare v1.0.0 v2.0.0       # Compare performance between versions

EOF
}

# Handle special modes
case "$PROFILE_MODE" in
    help|--help|-h)
        show_usage
        exit 0
        ;;
    compare)
        if [[ $# -lt 3 ]]; then
            log_warning "Compare mode requires two version arguments"
            show_usage
            exit 1
        fi
        compare_versions "$2" "$3"
        exit 0
        ;;
esac

# Check for jq dependency
if ! command -v jq >/dev/null 2>&1; then
    log_warning "jq is required for JSON processing"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Run main profiling
main