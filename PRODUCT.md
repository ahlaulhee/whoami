# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Astro, sitio estático, desplegado en Cloudflare Pages (`ahlaulhee.pages.dev`; `ahlaulhee.dev` más adelante). npm.

## Users

- Usuarios de Linux, en inglés, que quieren reproducir un setup concreto: Fedora 45 mínimo, NVIDIA, Mango (compositor con scroll basado en dwl) con barra en Quickshell, Neovim. Leen con la terminal abierta al lado y copian comandos.
- Visitantes de la página personal de Alex: about, proyectos, links.

## Product Purpose

Sitio personal de Alex Laulhe: blog de guías de configuración probadas en su equipo real, más su about/portafolio (reemplaza el antiguo `whoami`). Éxito = el lector reproduce el setup copiando bloques, y cada guía sigue siendo cierta para la versión que declara.

## Positioning

Guías sacadas de un equipo de uso diario real (RTX 5070, dos monitores VRR, Mango 0.18), con URL versionada, sello "Tested on" y enlaces a un commit fijo de los dotfiles.

## Capabilities and Constraints

- Artículos con etiquetas, serie con navegación anterior/siguiente, tabla de contenidos, botón de copiar código, RSS, "Tested on" + "Updated".
- Portada: about (edad y antigüedad laboral calculadas), proyectos, links.
- Fuera por ahora: búsqueda, comentarios, analytics, newsletter, modo claro, i18n.
- Un artículo nuevo por versión; slug con versión (`/blog/fedora-45-setup/`). Contenido CC0 1.0. Solo capturas, sin video.

## Brand Commitments

- Nombre "ahlaulhee"; Alex Laulhe, Córdoba, Argentina.
- Visual fijado por el usuario: inspirado en Spectre (sin copiar su código, que no tiene licencia), paleta Paradise, Geist + Geist Mono, solo oscuro.

## Evidence on Hand

- Copy del portafolio actual, proyecto WTTG3 Assistant, GitHub @ahlaulhee, la marca ASCII "ahl" (generada por `scripts/gen-ascii.js`).
- Artículos de Fedora y Mango basados en investigación verificada (notes/research/); lo que solo se puede comprobar en la máquina real está en notes/checklists/. El de Neovim se publica como "Work in progress". La guía de dwl quedó como borrador.

## Product Principles

1. Reproducibilidad antes que estética: cada comando es copiable y probado.
2. La versión es parte de la verdad: nunca se reescribe una guía vieja para una versión nueva.
3. Mínimo y mantenible: sin funciones que no tengan uso hoy.
