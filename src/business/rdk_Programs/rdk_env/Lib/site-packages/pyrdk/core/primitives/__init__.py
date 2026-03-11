from typing import Dict
from abc import ABC


class Primitive(ABC):
    PT_NAME = ""
    PT_TYPE = ""

    def __init__(self, params: Dict, conditions: Dict):
        if conditions is None:
            conditions = {}
        assert isinstance(conditions, dict), "conditions must be a dict"
        self.conditions = conditions
        if params is None:
            params = {}
        assert isinstance(params, dict), "params must be a dict"
        self.params = params