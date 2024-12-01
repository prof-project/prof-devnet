#!/bin/bash

ENCLAVE_NAME=$1
LOG_DIR="logs/run-$(date +%Y%m%d-%H%M%S)"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
echo "Created log directory: $LOG_DIR"

# Function to wait for services
wait_for_services() {
    echo "Waiting for Kurtosis services to be ready..."
    ATTEMPTS=0
    MAX_ATTEMPTS=60  # 5 minutes maximum wait time
    
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        SERVICE_COUNT=$(kurtosis enclave inspect "$ENCLAVE_NAME" | grep RUNNING | wc -l)
        if [ "$SERVICE_COUNT" -gt 20 ]; then  # Increased threshold
            echo "Found $SERVICE_COUNT running services"
            sleep 5  # Reduced wait time
            return 0
        fi
        echo "Waiting for services to start... ($SERVICE_COUNT running)"
        sleep 5
        ATTEMPTS=$((ATTEMPTS + 1))
    done
    
    echo "Timeout waiting for services"
    return 1
}

# Function to start logging for a service
start_service_logger() {
    local service=$1
    local logfile="$LOG_DIR/${service}.log"
    local max_retries=3
    local retry=0
    
    # Immediately start mev-flood-2 logger
    if [ "$service" = "mev-flood-2" ]; then
        echo "Starting priority logger for mev-flood-2"
        kurtosis service logs "$ENCLAVE_NAME" "$service" -f > "$logfile" 2>&1 &
        local pid=$!
        echo $pid >> "$LOG_DIR/pids"
        return 0
    fi
    
    while [ $retry -lt $max_retries ]; do
        echo "Starting logger for $service -> $logfile (attempt $((retry + 1)))"
        
        # Start the logger and capture its PID
        kurtosis service logs "$ENCLAVE_NAME" "$service" -f > "$logfile" 2>&1 &
        local pid=$!
        echo $pid >> "$LOG_DIR/pids"
        
        # Wait a moment to ensure the process started successfully
        sleep 1
        
        # Check if the process is still running
        if kill -0 $pid 2>/dev/null; then
            echo "Successfully started logger for $service (PID: $pid)"
            return 0
        else
            echo "Failed to start logger for $service, retrying..."
            retry=$((retry + 1))
            sleep 1
        fi
    done
    
    echo "Failed to start logger for $service after $max_retries attempts"
    return 1
}

# Main execution
# Start mev-flood-2 immediately if it exists
echo "Checking for mev-flood-2..."
if kurtosis enclave inspect $ENCLAVE_NAME | grep -q "mev-flood-2.*RUNNING"; then
    start_service_logger "mev-flood-2"
fi

wait_for_services

# Get all running services
ALL_SERVICES=$(kurtosis enclave inspect $ENCLAVE_NAME | grep RUNNING | awk '{print $2}' | grep -v '^RUNNING$' | sort -u)

# Clear/create PID file
echo -n > "$LOG_DIR/pids"

# Start priority services first (mev-flood)
echo "Starting priority services (mev-flood)..."
echo "$ALL_SERVICES" | grep "mev-flood" | while read SERVICE; do
    if [ ! -z "$SERVICE" ]; then
        start_service_logger "$SERVICE"
    fi
done

# Start remaining services
echo "Starting remaining services..."
echo "$ALL_SERVICES" | grep -v "mev-flood" | while read SERVICE; do
    if [ ! -z "$SERVICE" ]; then
        start_service_logger "$SERVICE"
    fi
done

# Store the service count
SERVICE_COUNT=$(echo "$ALL_SERVICES" | wc -l)
RUNNING_PIDS=$(cat "$LOG_DIR/pids" | wc -l)
echo "Started $RUNNING_PIDS loggers out of $SERVICE_COUNT services"
echo "Logs are being written to $LOG_DIR/"

if [ $RUNNING_PIDS -lt $SERVICE_COUNT ]; then
    echo "Warning: Not all loggers were started successfully"
    echo "Expected: $SERVICE_COUNT, Running: $RUNNING_PIDS"
fi

echo "Press Ctrl+C to stop logging"

# Trap Ctrl+C to clean up
trap 'echo "Stopping loggers..."; kill $(cat "$LOG_DIR/pids" 2>/dev/null); exit' INT TERM

# Keep script running and periodically verify loggers
while true; do
    sleep 30
    ACTIVE_PIDS=0
    while read pid; do
        if kill -0 $pid 2>/dev/null; then
            ACTIVE_PIDS=$((ACTIVE_PIDS + 1))
        fi
    done < "$LOG_DIR/pids"
    echo "Active logger processes: $ACTIVE_PIDS"
done 