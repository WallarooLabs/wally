#! /bin/bash
set -x
set -o errexit
set -o nounset

echo "Building Wallaroo docker image and pushing to Bintray..."
## Sets Wallaroo Docker repo host to Bintray repo.
wallaroo_docker_repo_host=wallaroo-labs-docker-wallaroolabs.bintray.io
if [[ "$TRAVIS_BRANCH" == "release" ]]
then
	# Set version to output of VERSION file
	version=$(< VERSION)
	wallaroo_docker_image_repo=release
	docker_image_tag=$version
elif [[ "$TRAVIS_BRANCH" == *"release-"* ]]
then
	## Sets repo to dev for Wallaroo Docker image
	wallaroo_docker_image_repo=dev
	docker_image_tag=$(git describe --tags --always)
fi
wallaroo_docker_image=wallaroo:$docker_image_tag
wallaroo_docker_image_path=$wallaroo_docker_repo_host/$wallaroo_docker_image_repo/$wallaroo_docker_image
## Conditional check for whether current image tag exists in repo, does not
## re-upload image if so. Otherwise builds docker image and uploads to Bintray.
returned_tag_name=$(curl -s "https://$wallaroo_docker_repo_host/v2/$wallaroo_docker_image_repo/wallaroo/tags/list" | jq ".tags" | grep -Po "(?<=\")$docker_image_tag(?=\")" || echo "0")
if [[ "$returned_tag_name" == "$docker_image_tag" ]]
then
	echo "Docker image: $wallaroo_docker_image_path already exists."
	exit 0
else
	# insert version into UI
	version=$(< VERSION)
	sed -i -- "s/{{ book.wallaroo_version }}/$version/g" monitoring_hub/apps/metrics_reporter_ui/web/static/js/buffy-ui/components/applications/VersionAlert.js
	# build the image
	docker login -u wallaroolabs -p $DOCKER_PASSWORD $wallaroo_docker_repo_host
	make release-monitoring_hub-apps-metrics_reporter_ui
	docker build -t $wallaroo_docker_image_path .
	docker push $wallaroo_docker_image_path
	echo "Built and pushed image $wallaroo_docker_image_path successfully."
fi
