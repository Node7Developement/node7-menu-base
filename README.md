[README.md](https://github.com/user-attachments/files/30314813/README.md)
# node7-menu-base

NODE7 RedM menu base for nested RDR-style menus.

## Purpose

This resource is a shared menu library. Clothing, shops, admin panels, crafting, and other resources can open menus through this instead of building their own NUI.

Normal menus do not require ACE permissions.

## Start order

ensure node7-menu-base

Resources that use it should start after it.

## Client usage

Trigger the data event and open a menu with elements. Elements can be normal actions, sliders, or nested categories.

Event:
node7-menu-base:getData

Export:
exports['node7-menu-base']:GetMenuData()

## ACE

The included permissions.cfg only protects optional diagnostics. It does not gate normal menu use.

exec resources/[node7]/node7-menu-base/permissions.cfg
