# wink

Social app that allows users to discover others within close-proximity range and ping each other to know each other more!

## Project Description
Below are the hand written diagrams for brief overview of the user flow of this app.

![project brainstorm image 1](/docs/images/brainstorm_1.png)
![project brainstorm image 2](/docs/images/brainstorm_2.png)

> At least 2 users are required for the user flow to happen

1. User A opens the app (wink)
1. Wink utilises the local device's bluetooth to scan other devices nearby with Wink service installed (using the service ID attached to the application), followd by displaying the available nearby devices
1. User A then clicks one of the displayed devices to make connection with User B
1. Wink will make an API call to the server using the discovered deviceID from the discovery phase.
1. User B will receive push notification from the server that user A has liked (pinged) the user.
1. User B will also send a like (ping) back to User A, which will be handled by the API service
1. Both Users A and B have liked each other, which will then reveal their pre-stated social media ID to continue further conversation
1. End of the user flow

## 2. Technologies Used
* Flutter was used to easily compile app for cross-platforms (ios & Android)
