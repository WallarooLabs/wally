# Copyright 2017 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.


from recovery import test_recovery_machida
from recovery import test_recovery_pony
from restart_without_resilience import test_restart_machida
from restart_without_resilience import test_restart_pony
from log_rotation import test_log_rotation_external_trigger_no_recovery_pony
from log_rotation import test_log_rotation_external_trigger_no_recovery_machida
from log_rotation import test_log_rotation_external_trigger_recovery_machida
from log_rotation import test_log_rotation_external_trigger_recovery_pony
from log_rotation import test_log_rotation_file_size_trigger_no_recovery_machida
from log_rotation import test_log_rotation_file_size_trigger_no_recovery_pony
from log_rotation import test_log_rotation_file_size_trigger_recovery_machida
from log_rotation import test_log_rotation_file_size_trigger_recovery_pony
