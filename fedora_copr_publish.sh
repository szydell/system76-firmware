#!/usr/bin/env bash
#
# Get package version from upstream git tags and build for Fedora COPR
#
# ----------------------------------------------------------------------------
# 2025-12-15 Marcin Szydelski
#		switch to git tags as version source (debian/changelog no longer maintained)
# 2021-01-09 Marcin Szydelski
#		init

# config
outdir="$(pwd)/.rpkg-build"
export outdir

# fetch upstream
git fetch upstream || { echo "Failed to fetch upstream"; exit 1; }

# merge
git checkout master
git merge upstream/master -m "fetch upstream" --log

[ -d "${outdir}" ] && rm -rf "${outdir}"

# Get latest version from upstream git tags (format: X.Y.Z)
version=$(git tag -l --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

if [ -z "$version" ]; then
	echo "No valid version tag found in upstream"
	exit 1
fi

# Get our latest release number for this version
_tmp=$(git tag --list "system76-firmware-${version}-"'*' | sort -t '-' -k 4 -n -r | head -1)
release=${_tmp##*-}

if [ -z "$release" ]; then
	release=1
else
	if ! [[ "$release" =~ ^[0-9]+$ ]]; then
		echo "Release should be a number"
		exit 2
	fi
	# increment release number
	((release++))
fi

echo "Building version: ${version}-${release}"

# as a workaround set static version in spec file
sed -i "s#^Version:    .*#Version:    ${version}#" system76-firmware.spec.rpkg
sed -i "s#^Release:    .*#Release:    ${release}#" system76-firmware.spec.rpkg
git commit -m "bump Version to: ${version}-${release}" system76-firmware.spec.rpkg

#test & build srpm
mkdir "$outdir"
rpkg local --outdir="$outdir" || { echo "rpkg local failed"; exit 4; }

# rpkg tag
rpkg tag --version="${version}" --release="${release}"

srpm="$(ls .rpkg-build/system76-firmware-*.src.rpm)"

# publish / build oficially

copr-cli build system76 "$srpm" || { echo "Copr build failed"; exit 5; }

# store in repo
git push || { echo "Git push failed"; exit 6; }
git push --tags || { echo "Git push --tags failed"; exit 6; }

# clear

if [ -d "$outdir" ]; then
	rm -rf "$outdir"
fi
