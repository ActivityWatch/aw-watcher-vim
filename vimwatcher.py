import logging
from typing import Optional
from time import sleep
from datetime import datetime, timezone, timedelta
import json
import sys

from aw_core import dirs
from aw_core.models import Event
from aw_client.client import ActivityWatchClient


name = "aw-watcher-vim"
logger = logging.getLogger(name)


def load_config():
    from configparser import ConfigParser
    from aw_core.config import load_config as _load_config
    default_config = ConfigParser()
    default_config[name] = {
        "poll_time": "5.0"
    }

    return _load_config(name, default_config)


def get_vim_data():
    data = {
        # 'file': vim.current.buffer.name
    }
    return data


def main():
    logging.basicConfig(level=logging.INFO)
    config_dir = dirs.get_config_dir(name)

    config = load_config()
    poll_time = config[name].getfloat("poll_time")

    aw = ActivityWatchClient(name, testing=False)
    bucketname = "{}_{}".format(aw.client_name, aw.client_hostname)
    aw.setup_bucket(bucketname, 'currently-editing')
    aw.connect()

    data = None

    print("started")
    run = True
    while run:
        data = json.loads(sys.stdin.readline())
        with open('test.log', 'a') as f:
            json.dump(data, f)
        if data[1] == "stop":
            run = False

        # data = get_vim_data()

        if data:
            event = Event(timestamp=datetime.now(timezone.utc), data=data)
            aw.heartbeat(bucketname, event, pulsetime=poll_time + 1, queued=True)
        sleep(5)

    print("finished")


main()
