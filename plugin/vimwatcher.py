import logging
import json
import sys
from datetime import datetime, timezone

from aw_core import dirs
from aw_core.models import Event
from aw_client.client import ActivityWatchClient

logging.basicConfig(level=logging.INFO)

name = "aw-watcher-vim"
logger = logging.getLogger(name)

client_logger = logging.getLogger("aw_client")
client_logger.setLevel(logging.WARNING)


def load_config():
    from configparser import ConfigParser
    from aw_core.config import load_config as _load_config
    default_config = ConfigParser()
    default_config[name] = {
        "pulsetime": "10.0"
    }

    return _load_config(name, default_config)


def send(h, content):
    msg = json.dumps([h, content])
    print(msg)


def main():
    config_dir = dirs.get_config_dir(name)

    config = load_config()
    pulsetime = config[name].getfloat("pulsetime")

    aw = ActivityWatchClient(name, testing=False)
    bucketname = "{}_{}".format(aw.client_name, aw.client_hostname)
    aw.create_bucket(bucketname, 'app.editor.activity', queued=True)
    aw.connect()

    for chunk in sys.stdin:
        msg = json.loads(chunk)
        if "action" not in msg:
            logger.error("No action in msg: {}".format(msg))
        if msg["action"] == "stop":
            aw.disconnect()
            return
        elif msg["action"] == "update":
            timestamp = datetime.now(timezone.utc)
            event = Event(timestamp=timestamp, data=msg["data"])
            aw.heartbeat(bucketname, event, pulsetime=pulsetime, queued=True)
        else:
            logger.error("Invalid action: {}".format(msg["action"]))

main()
