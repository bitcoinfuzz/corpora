#!/usr/bin/env bash
set -euo pipefail

boost_config="${BOOST_PREFIX}/lib/cmake/Boost-${BOOST_VERSION}/BoostConfig.cmake"
if [[ -f "${boost_config}" ]]; then
  exit 0
fi

mkdir -p "$(dirname "${BOOST_PREFIX}")"

workdir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/boost-${BOOST_VERSION}.XXXXXX")"
archive="${workdir}/boost.tar.gz"
srcdir="${workdir}/boost-${BOOST_VERSION}"
stage_prefix="${BOOST_PREFIX}.new"

cleanup() {
  rm -rf "${workdir}" "${stage_prefix}"
}

trap cleanup EXIT

rm -rf "${BOOST_PREFIX}" "${stage_prefix}"

curl --fail --show-error --location \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --output "${archive}" \
  "${BOOST_URL}"

tar -tzf "${archive}" >/dev/null
tar -xzf "${archive}" -C "${workdir}"

if [[ ! -d "${srcdir}" ]]; then
  echo "Expected Boost source directory ${srcdir} was not created" >&2
  exit 1
fi

cmake -S "${srcdir}" -B "${srcdir}/build" \
  -DCMAKE_C_COMPILER="${CC}" \
  -DCMAKE_CXX_COMPILER="${CXX}" \
  -DCMAKE_INSTALL_PREFIX="${stage_prefix}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DBOOST_INCLUDE_LIBRARIES="${BOOST_LIBRARIES}"

cmake --build "${srcdir}/build" --parallel "$(nproc)"
cmake --install "${srcdir}/build"

mv "${stage_prefix}" "${BOOST_PREFIX}"
