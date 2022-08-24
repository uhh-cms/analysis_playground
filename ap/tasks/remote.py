# coding: utf-8

"""
Tasks dealing with remote jobs.
"""

import os

from columnflow.tasks.framework.remote import BundleRepo as CFBundleRepo, HTCondorWorkflow

from hbt.tasks.base import APTask


# get the relative path to CF_BASE
cf_rel = os.path.relpath(os.environ["CF_BASE"], os.environ["HBT_BASE"])


class BundleRepo(APTask, CFBundleRepo):

    # amend exclude files
    exclude_files = [
        "docs", "tests", "data", "assets", ".law", ".setups", ".data", ".github",
    ] + [os.path.join(cf_rel, path) for path in CFBundleRepo.exclude_files]

    def get_repo_path(self):
        # change the path to the repo
        return os.environ["AP_BASE"]


# tell the HTCondorWorkflow in cf to use the custom BundleRepo
HTCondorWorkflow.dep_BundleRepo = BundleRepo
