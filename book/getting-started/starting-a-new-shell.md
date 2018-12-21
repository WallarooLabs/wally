# Starting a new shell for Wallaroo

In this section, we're going to review how you can start a new shell for Wallaroo regardless of how you installed it.

## Wallaroo in Docker

For each Shell you're expected to setup, you'd have to run the following to enter the Wallaroo Docker container:

Enter the Wallaroo Docker container:

{% codetabs name="Machida", type="bash" -%}
docker exec -it wally env-setup
{%- language name="Machida3", type="bash" -%}
docker exec -it wally env-setup -p python3
{%- endcodetabs %}

This command will start a new Bash shell within the container, which will run the `env-setup` script to ensure our persistent Python `virtualenv` is set up.

If your Wallaroo docker container isn't set up or running, you'll get an error with the above command. Please see [Setting Up Your Environment for Wallaroo in Docker](book/getting-started/docker-setup.md) for details on how to set up and start your Wallaroo Docker enviroment.

## Wallaroo in Vagrant

For each Shell you're expected to setup, you'd have to run the following to access the Vagrant Box:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/vagrant
vagrant ssh
```

If your Wallaroo vagrant box isn't set up or running, you'll get an error with the above command. Please see [Setting Up Your Environment for Wallaroo in Vagrant](book/getting-started/vagrant-setup.md) for details on how to set up and start your Wallaroo Vagrant enviroment.

## Wallaroo from source and Wallaroo Up

For each Shell you're expected to setup, you'd have to run the following to configure the Wallaroo environment:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}
source bin/activate
```

This command will set up the environment variables for running Wallaroo Applications.
