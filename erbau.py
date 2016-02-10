#!/usr/bin/env python3

import click
import subprocess

spike_dir = 'spike'
giles_sender_dir = 'giles/sender/'
giles_receiver_dir = 'giles/receiver/'

def compile(dir, filebase):
    subprocess.call('cd ' + dir + ' && ponyc', shell=True)

def cross_compile(dir, filebase):
    subprocess.call('cd ' + dir + ' && rpxp && ' + remove(filebase), shell=True)

def remove(filebase):
    return 'rm ' + filebase + '.bc ' + filebase + '.ll ' + filebase + '.o'

@click.command()
@click.option('--arm', is_flag=True, default=False)
def cli(arm):
    if arm:
        cross_compile(spike_dir, 'spike')
        cross_compile(giles_sender_dir, 'sender')
        cross_compile(giles_receiver_dir, 'receiver')
    else:
        compile(spike_dir, 'spike')
        compile(giles_sender_dir, 'sender')
        compile(giles_receiver_dir, 'receiver')

if __name__ == "__main__":
    cli()