import logging
import json
import sys
from datetime import datetime

from aw_core import dirs
from aw_core.models import Event
from aw_client.client import ActivityWatchClient


name = "aw-watcher-vim"
logger = logging.getLogger(name)

#client_logger = logging.getLogger("aw_client")
#client_logger.setLevel(40)


def load_config():
    from configparser import ConfigParser
    from aw_core.config import load_config as _load_config
    default_config = ConfigParser()
    default_config[name] = {
        "min_delay": "5.0",
        "pulsetime": "10.0"
    }

    return _load_config(name, default_config)


def send(h, content):
    msg = json.dumps([h, content])
    print(msg)


def main():
    logging.basicConfig(level=logging.INFO)
    config_dir = dirs.get_config_dir(name)

    config = load_config()
    min_delay = config[name].getfloat("min_delay")
    pulsetime = config[name].getfloat("pulsetime")

    aw = ActivityWatchClient(name, testing=False)
    bucketname = "{}_{}".format(aw.client_name, aw.client_hostname)
    aw.create_bucket(bucketname, 'app.editor.current-activity', queued=True)
    aw.connect()

    i = 1
    logger.info("Starting read loop")
    for chunk in sys.stdin:
        logger.info("A")
        i, data = json.loads(chunk)
        if data == "stop":
            break
        elif data == "config":
            send("config", {"min_delay": min_delay})
        elif data:
            logger.info("Sending heartbeat")
            timestamp = datetime.utcfromtimestamp(data.pop("timestamp"))
            event = Event(timestamp=timestamp, data=data)
            aw.heartbeat(bucketname, event, pulsetime=pulsetime, queued=True)
        else:
            logger.info("Test")


main()
