# Build image

We use [Calendar Versioning](https://calver.org/) for tagging the Docker image. The specific format we adhere to is `YYYY.0M.0D.MICRO`. So if we were releasing the CI Docker image on `05-30-2018`, we'd tag it as follows: `2018.05.30.1`, where the MICRO value will increment for each release on that given day.

**NOTE:** You must replace the `YYYY.0M.0D.MICRO` tag in the commands below with the appropriate tag!

```bash
docker build -t wallaroolabs/wallaroo-ci:YYYY.0M.0D.MICRO .
```

# Run image to test

Will get you a bash shell in the image to try cloning Wallaroo into where you can test a build to make sure everything will work before pushing.

```bash
docker run --name wallaroolabs-wallaroo-ci-standard --rm -i -t wallaroolabs/wallaroo-ci:YYYY.0M.0D.MICRO bash
```

# Push to dockerhub

You'll need credentials for the Wallaroo Labs Docker Hub account. Talk to @dipinhora, @JONBRWN, or @seantallen for access.

```bash
docker push wallaroolabs/wallaroo-ci:YYYY.0M.0D.MICRO
```
