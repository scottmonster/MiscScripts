#!/bin/bash

# Set the target IP address (replace with your router's IP)
target_ip="8.8.8.8"

# Function to check if the target is reachable
check_reachability() {
    ping -c 1 "$target_ip" > /dev/null
}

echo ""
while check_reachability; do
		echo "waiting for router to go offline..."
    sleep 1
done

# Record start time
start_time=$(date +%s)
echo "Can not ping host: $target_ip. Starting test."

while ! check_reachability; do
		echo "Waiting for the router to come back online..."
    sleep 1
done

# Record end time
end_time=$(date +%s)

# Calculate the downtime
downtime=$((end_time - start_time))

echo "Network downtime: $downtime seconds"
