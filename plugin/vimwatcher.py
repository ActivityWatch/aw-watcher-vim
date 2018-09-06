import logging
import json
import sys
from datetime import datetime, timezone

from aw_core.log import setup_logging
from aw_core.models import Event
from aw_client.client import ActivityWatchClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

name = "aw-watcher-vim"


def load_config():
    from configparser import ConfigParser
    from aw_core.config import load_config as _load_config
    default_config = ConfigParser()
    default_config[name] = {
        "pulsetime": "20.0"
    }

    return _load_config(name, default_config)


def send(h, content):
    msg = json.dumps([h, content])
    print(msg)


def main(testing=False):
    client_logger = logging.getLogger("aw_client")
    if not testing:
        client_logger.setLevel(logging.WARNING)
    setup_logging(name, testing=testing, log_stderr=True, log_file=testing)

    config = load_config()
    pulsetime = config[name].getfloat("pulsetime")

    aw = ActivityWatchClient(name, testing=testing)
    bucketname = "{}_{}".format(aw.client_name, aw.client_hostname)
    aw.create_bucket(bucketname, 'app.editor.activity', queued=True)
    aw.connect()

    for chunk in sys.stdin:
        msg = json.loads(chunk)
        if "action" not in msg:
            logger.error("No action in msg: {}".format(msg))
        elif msg["action"] == "update":
            timestamp = datetime.now(timezone.utc)
            event = Event(timestamp=timestamp, data=msg["data"])
            aw.heartbeat(bucketname, event, pulsetime=pulsetime, queued=True, commit_interval=3)
        else:
            logger.error("Invalid action: {}".format(msg["action"]))


if __name__ == "__main__":
    main()
