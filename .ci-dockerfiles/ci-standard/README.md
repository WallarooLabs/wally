# Build image

```bash
docker build -t wallaroolabs/wallaroo-ci:standard .
```

# Run image to test

Will get you a bash shell in the image to try cloning Wallaroo into where you can test a build to make sure everything will work before pushing.

```bash
docker run --name wallaroolabs-wallaroo-ci-standard --rm -i -t wallaroolabs/wallaroo-ci:standard bash
```

# Push to dockerhub

You'll need credentials for the Wallaroo Labs Docker Hub account. Talk to @dipinhora, @JONBRWN, or @seantallen for access.

```bash
docker push wallaroolabs/wallaroo-ci:standard
```
