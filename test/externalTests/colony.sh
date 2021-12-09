#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# This file is part of solidity.
#
# solidity is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# solidity is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with solidity.  If not, see <http://www.gnu.org/licenses/>
#
# (c) 2019 solidity contributors.
#------------------------------------------------------------------------------

set -e

source scripts/common.sh
source test/externalTests/common.sh

verify_input "$1"
SOLJSON="$1"

function compile_fn { yarn run provision:token:contracts; }
function test_fn { yarn run test:contracts; }

function colony_test
{
    local repo="https://github.com/solidity-external-tests/colonyNetwork.git"
    local branch=develop_080
    local config_file="truffle.js"
    local settings_presets=(
        #legacy-no-optimize        # Compiles but tests run out of gas
        #legacy-optimize-evm-only  # Compiles but tests run out of gas
        legacy-optimize-evm+yul
    )

    local selected_optimizer_presets
    selected_optimizer_presets=$(circleci_select_steps_multiarg "${settings_presets[@]}")
    print_optimizer_presets_or_exit "$selected_optimizer_presets"

    setup_solcjs "$DIR" "$SOLJSON"
    download_project "$repo" "$branch" "$DIR"

    neutralize_package_json_hooks
    force_truffle_compiler_settings "$config_file" "${DIR}/solc" "$(first_word "$selected_optimizer_presets")"
    yarn
    git submodule update --init

    cd lib
    rm -Rf dappsys
    git clone https://github.com/solidity-external-tests/dappsys-monolithic.git -b master_080 dappsys
    cd ..

    replace_version_pragmas
    force_solc_modules "${DIR}/solc"

    for preset in $selected_optimizer_presets; do
        truffle_run_test "$config_file" "${DIR}/solc" "$preset" compile_fn test_fn
    done
}

external_test ColonyNetworks colony_test
