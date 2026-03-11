from datetime import datetime
import pytz


class TimeUtil:

    @staticmethod
    def timestamp_to_nanoseconds(timestamp, time_zone="UTC") -> str:
        tz = pytz.timezone(time_zone)
        dt = datetime.fromtimestamp(timestamp // 1000000000, tz)
        s = dt.strftime("%Y-%m-%dT%H:%M:%S")
        s += "." + str(int(timestamp % 1000000000)).zfill(9) + "Z"
        return s

    @staticmethod
    def timestamp_to_microseconds(timestamp, time_zone="UTC") -> str:
        tz = pytz.timezone(time_zone)
        dt = datetime.fromtimestamp(timestamp // 1000000000, tz)
        string = dt.strftime("%Y-%m-%dT%H:%M:%S")
        string += "." + str(int(timestamp % 1000000000)).zfill(9)[:-3] + "Z"
        return string
