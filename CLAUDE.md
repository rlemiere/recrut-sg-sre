# CLAUDE.md

## Project layout

This project is a url shortener website. It is composed of the following
components :

- folder `frontend`: The frontend app in react

- folder `backend`: The backend app in python using fastapi

- folder `terraform`: The infrastructure to deploy the whole application.

This project will feature a postgresql database for the backend.

## Frontend

The frontend app is a react app composed of a single page. This page has a
single text field in which a user inputs an url with a button to send to the
backend. When sent to the backend, the backend will return the shortened link
to use.

## Backend

The backend app is a python uv-based project using fast api. It should serve
the following endpoints :

- `POST /links` : Receives a link from the user, shortens it, and stores it in
  the database.

- `GET /l/<link_id>` : Returns `302 Moved` to the proper link, or 404 page.

### Database structure

The database structure should be very simple :

A single table containing as primary key the id of the link, and a text field
containing the link to return to.

### Construction of the link id

The id of the link is created the following way :

1. The url is hashed using md5 algorithm

2. The **bytes** of the hash are encoded using base62

3. The base62 string is truncated to 8 chars.

## Infrastructure
