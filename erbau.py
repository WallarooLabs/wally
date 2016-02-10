#!/usr/bin/env python3

import click
import subprocess

@click.command()
@click.option('--arm', is_flag=True, default=False)
def cli(arm):
    compile = 'ponyc' if not arm else 'rpxp'
    subprocess.Popen(['cd', 'spike'])
    subprocess.Popen([compile])
    subprocess.Popen(['cd', '../giles/sender'])
    subprocess.Popen([compile])
    subprocess.Popen(['cd', '../receiver'])
    subprocess.Popen([compile])
    subprocess.Popen(['cd', '../..'])

if __name__ == "__main__":
    cli()