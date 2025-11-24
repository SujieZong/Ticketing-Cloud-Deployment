# locustfile.py
#
# This Locust file is designed for a "Sequential Burst" load test.
#
# Scenario:
# 1. It targets a SINGLE event and venue (e.g., Event1 at Venue1).
# 2. On startup, it generates a list of all available seats for the target venue.
# 3. Virtual users fetch seats from this shared list in a queue-like fashion,
#    ensuring each seat is attempted for purchase only once.
# 4. After a successful purchase, 50% of users will make a follow-up request to
#    the Query Service to verify their ticket.
#
# How to Run:
# 1. Install dependencies: pip install locust pyyaml
# 2. Set environment variables for the service hosts:
#    export PURCHASE_SERVICE_HOST="http://localhost:8081"
#    export QUERY_SERVICE_HOST="http://localhost:8082"
# 3. Run Locust:
#    locust -f load_testing/locustfile.py
#

import os
import yaml
import random
from itertools import product
from queue import Queue
from locust import HttpUser, task, constant, events

# --- Configuration ---

# Read service hosts from environment variables
PURCHASE_HOST = os.getenv("PURCHASE_SERVICE_HOST", "http://localhost:8081")
QUERY_HOST = os.getenv("QUERY_SERVICE_HOST", "http://localhost:8082")

# Target Event and Venue for this test
TARGET_EVENT_ID = "Event1"
TARGET_VENUE_ID = "Venue1"
VENUES_FILE_PATH = "PurchaseService/src/main/resources/venues.yml"

# Global queue to hold all seats. This will be populated once on startup.
SEAT_QUEUE = Queue()

# --- Utility Functions ---


def load_venue_layout(venue_id: str):
    """
    Loads the layout for a specific venue from the venues.yml file.
    """
    try:
        with open(VENUES_FILE_PATH, 'r') as f:
            venues_data = yaml.safe_load(f)
            venue_config = venues_data.get(
                "venues", {}).get("map", {}).get(venue_id)
            if not venue_config:
                print(
                    f"FATAL: VenueID '{venue_id}' not found in {VENUES_FILE_PATH}")
                exit(1)

            zones_config = venue_config.get("zones")
            return {
                "zone_count": zones_config.get("zone-count", 0),
                "row_count": zones_config.get("row-count", 0),
                "col_count": zones_config.get("col-count", 0),
            }
    except FileNotFoundError:
        print(
            f"FATAL: {VENUES_FILE_PATH} not found. Make sure you are running locust from the project root.")
        exit(1)
    except Exception as e:
        print(f"FATAL: Error parsing {VENUES_FILE_PATH}: {e}")
        exit(1)


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """
    This function is called once when the test starts.
    It generates all possible seats and puts them into the shared queue.
    """
    print("--- Populating seat queue ---")
    layout = load_venue_layout(TARGET_VENUE_ID)
    zone_count = layout["zone_count"]
    row_count = layout["row_count"]
    col_count = layout["col_count"]

    if zone_count == 0:
        print("FATAL: Venue layout has 0 zones. Stopping test.")
        environment.runner.quit()
        return

    # Generate all combinations of (zone, row, column)
    all_seats = product(range(1, zone_count + 1),
                        range(1, row_count + 1), range(1, col_count + 1))

    seat_count = 0
    for zone, row, col in all_seats:
        SEAT_QUEUE.put({
            "zoneId": zone,
            "row": str(row),
            "column": str(col)
        })
        seat_count += 1

    print(
        f"--- Seat queue populated with {seat_count} seats for Venue '{TARGET_VENUE_ID}' ---")


# --- Locust User Class ---

class SequentialTicketPurchaser(HttpUser):
    """
    This user fetches a unique seat from the global queue and attempts to purchase it.
    """
    wait_time = constant(1)  # Wait 1 second between tasks
    host = PURCHASE_HOST  # Default host for the client

    @task
    def purchase_ticket_sequentially(self):
        try:
            seat_to_purchase = SEAT_QUEUE.get_nowait()
        except Exception:
            # Queue is empty, stop this user.
            print("Seat queue is empty. Stopping user.")
            self.stop(True)
            return

        request_body = {
            "eventId": TARGET_EVENT_ID,
            "venueId": TARGET_VENUE_ID,
            **seat_to_purchase
        }

        with self.client.post(
            "/purchase/api/v1/tickets",
            json=request_body,
            catch_response=True,
            name="/api/v1/tickets [purchase]"
        ) as response:
            if response.status_code == 201:
                response.success()

                # 50% chance to verify the ticket
                if random.random() < 0.5:
                    ticket_id = response.json().get("ticketId")
                    if ticket_id:
                        # Make a request to the Query Service
                        self.client.get(
                            f"{QUERY_HOST}/query/api/v1/tickets/{ticket_id}",
                            name="/api/v1/tickets/{ticketId} [query]"
                        )
            else:
                response.failure(
                    f"Failed to purchase seat {seat_to_purchase}. Status: {response.status_code}")

    def on_stop(self):
        """
        Called when a user is stopped.
        """
        print("User stopped.")
