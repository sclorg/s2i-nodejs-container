#!/bin/env python3

# MIT License
#
# Copyright (c) 2018-2019 Red Hat, Inc.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import sys
import json
import logging
import os

from pathlib import Path
from typing import Dict, List, Any

IMAGESTREAMS_DIR: str = "imagestreams"


class ImageStreamChecker(object):
    version: str = ""

    def __init__(self, version: str):
        self.version = version
        self.results: Dict[Any, Any] = {}

    def load_json_file(self, filename: Path) -> Any:
        with open(str(filename)) as f:
            data = json.load(f)
            isinstance(data, Dict)
            return data

    def check_version(self, json_dict: Dict[Any, Any]) -> List[str]:
        res = []
        for tags in json_dict["spec"]["tags"]:
            print(
                f"check_version: Compare tags['name']:'{tags['name']}' against version:'{self.version}'"
            )
            # The name can be"<stream>" or "<stream>-elX" or "<stream>-ubiX"
            if tags["name"] == self.version or tags["name"].startswith(
                self.version + "-"
            ):
                res.append(tags)
        return res

    def check_latest_tag(self, json_dict: Dict[Any, Any]) -> bool:
        latest_tag_correct: bool = False
        for tags in json_dict["spec"]["tags"]:
            if tags["name"] != "latest":
                continue
            print(
                f"check_latest_tag: Compare tags['name']:'{tags['name']}' against version:'{self.version}'"
            )
            # The latest can link to either "<stream>" or "<stream>-elX" or "<stream>-ubiX"
            if tags["from"]["name"] == self.version or tags["from"]["name"].startswith(
                self.version + "-"
            ):
                latest_tag_correct = True
                print(f"Latest tag found.")
        return latest_tag_correct

    def check_imagestreams(self) -> int:
        p = Path(".")
        json_files = p.glob(f"{IMAGESTREAMS_DIR}/*.json")
        if not json_files:
            print(f"No json files present in {IMAGESTREAMS_DIR}.")
            return 0
        for f in json_files:
            print(f"Checking file {str(f)}.")
            json_dict = self.load_json_file(f)
            if not (self.check_version(json_dict) and self.check_latest_tag(json_dict)):
                print(
                    f"The latest version is not present in {str(f)} or in latest tag."
                )
                self.results[f] = False
        if self.results:
            return 1
        print("Imagestreams contains the latest version.")
        return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        logging.fatal("%s: %s", sys.argv[0], "VERSION as an argument was not provided")
        sys.exit(1)

    print(f"Version to check is {sys.argv[1]}.")
    isc = ImageStreamChecker(version=sys.argv[1])
    sys.exit(isc.check_imagestreams())
