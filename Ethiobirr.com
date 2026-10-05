<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">

<title>Live Location Share</title>

<!-- Leaflet Map -->
<link
  rel="stylesheet"
  href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
/>

<style>
* {
  box-sizing: border-box;
}

html,
body {
  margin: 0;
  padding: 0;
  width: 100%;
  min-height: 100%;
  font-family: Arial, sans-serif;
}

body {
  min-height: 100vh;
  background: linear-gradient(135deg,#101820,#243746);
  color: white;
}

/* Main card */

.card {
  width: 92%;
  max-width: 430px;
  margin: 50px auto;
  padding: 30px;
  border-radius: 22px;
  text-align: center;

  background: rgba(255,255,255,.10);

  backdrop-filter: blur(15px);

  box-shadow:
    0 20px 50px rgba(0,0,0,.4);
}

.icon {
  font-size: 55px;
  margin-bottom: 10px;
}

h1 {
  margin: 0 0 15px;
  font-size: 28px;
}

p {
  line-height: 1.6;
  opacity: .9;
}

button,
.button {
  display: block;
  width: 100%;
  padding: 16px;
  margin-top: 15px;

  border: none;
  border-radius: 12px;

  background: white;
  color: #111;

  font-size: 17px;
  font-weight: bold;

  text-decoration: none;

  cursor: pointer;
}

button:disabled {
  opacity: .55;
  cursor: not-allowed;
}

.status {
  margin-top: 20px;
  padding: 13px;

  border-radius: 10px;

  background: rgba(0,0,0,.25);
}

.location-info {
  margin-top: 18px;
  padding: 15px;

  border-radius: 12px;

  text-align: left;

  background: rgba(0,0,0,.25);
}

/* Map */

#mapPage {
  display: none;
}

#map {
  width: 100%;
  height: 100vh;
}

.panel {
  position: fixed;

  z-index: 9999;

  top: 15px;
  left: 15px;
  right: 15px;

  padding: 15px;

  border-radius: 15px;

  background: rgba(255,255,255,.95);

  color: #111;

  box-shadow:
    0 5px 25px rgba(0,0,0,.25);

  font-family: Arial,sans-serif;
}

.title {
  font-size: 19px;
  font-weight: bold;
  margin-bottom: 8px;
}

.live-status {
  font-weight: bold;
  color: green;
}

.map-button {
  margin-top: 10px;

  padding: 9px 12px;

  border-radius: 8px;

  border: none;

  background: #111;
  color: white;

  font-size: 13px;

  cursor: pointer;
}
</style>
</head>

<body>

<!-- =========================================================
     SHARE PAGE
========================================================= -->

<div id="sharePage">

  <div class="card">

    <div class="icon">📍</div>

    <h1>Location Share</h1>

    <p>
      Share your live location with permission.
    </p>

    <button
      id="startButton"
      onclick="startSharing()">
      Share My Location
    </button>

    <div
      id="status"
      class="status">
      Waiting for permission...
    </div>

    <div
      id="info"
      class="location-info"
      style="display:none;">

      <p>
        <b>Latitude:</b>
        <span id="lat">-</span>
      </p>

      <p>
        <b>Longitude:</b>
        <span id="lng">-</span>
      </p>

      <p>
        <b>Accuracy:</b>
        <span id="acc">-</span>
      </p>

      <p>
        <b>Last update:</b>
        <span id="time">-</span>
      </p>

    </div>

  </div>

</div>


<!-- =========================================================
     MAP PAGE
========================================================= -->

<div id="mapPage">

  <div class="panel">

    <div class="title">
      📍 Live Location
    </div>

    <div>
      Status:
      <span
        id="mapStatus"
        class="live-status">
        Connecting...
      </span>
    </div>

    <div>
      Accuracy:
      <span id="accuracy">
        -
      </span>
    </div>

    <div>
      Last update:
      <span id="mapTime">
        -
      </span>
    </div>

    <button
      class="map-button"
      onclick="centerOnUser()">
      🎯 Follow User
    </button>

  </div>

  <div id="map"></div>

</div>


<!-- Leaflet -->
<script
src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js">
</script>


<script>

/* =========================================================
   YOUR BACKEND
========================================================= */

const BACKEND_URL =
"https://script.google.com/macros/s/AKfycbyO6ith0ZzQRKIHD8xfQPhKnSH91w9fAp46LhjC1GWPLHpIAIQN-q4C_3aSs7BK2edW/exec";


/* =========================================================
   YOUR SHARE ID
========================================================= */

const SHARE_ID =
"AKfycbyO6ith0ZzQRKIHD8xfQPhKnSH91w9fAp46LhjC1GWPLHpIAIQN-q4C_3aSs7BK2edW";


/* =========================================================
   PAGE MODE
=========================================================

   Normal:
   index.html
   = Share page

   Map:
   index.html?map=1
   = Live map
========================================================= */

const params =
new URLSearchParams(
window.location.search
);

const mapMode =
params.get("map") === "1";


/* =========================================================
   SHOW CORRECT PAGE
========================================================= */

if (mapMode) {

  document
    .getElementById("sharePage")
    .style.display = "none";

  document
    .getElementById("mapPage")
    .style.display = "block";

} else {

  document
    .getElementById("sharePage")
    .style.display = "block";

  document
    .getElementById("mapPage")
    .style.display = "none";

}


/* =========================================================
   SHARE LOCATION
========================================================= */

let watchId = null;

let sharing = false;


function startSharing() {

  if (!navigator.geolocation) {

    setStatus(
      "❌ Location is not supported by this browser."
    );

    return;
  }


  if (sharing) {

    return;
  }


  setStatus(
    "📍 Requesting location permission..."
  );


  watchId =
    navigator.geolocation.watchPosition(

      function(position) {

        sharing = true;


        const latitude =
          position.coords.latitude;

        const longitude =
          position.coords.longitude;

        const accuracy =
          position.coords.accuracy;


        showLocation(
          latitude,
          longitude,
          accuracy
        );


        sendLocation(
          latitude,
          longitude,
          accuracy
        );

      },


      function(error) {

        if (error.code === 1) {

          setStatus(
            "❌ Location permission denied."
          );

        }

        else if (error.code === 2) {

          setStatus(
            "❌ Location unavailable."
          );

        }

        else if (error.code === 3) {

          setStatus(
            "❌ Location timed out."
          );

        }

        else {

          setStatus(
            "❌ Location error."
          );

        }

      },


      {

        enableHighAccuracy: true,

        maximumAge: 5000,

        timeout: 15000

      }

    );


  document
    .getElementById("startButton")
    .disabled = true;

}


/* =========================================================
   SEND LOCATION TO GOOGLE APPS SCRIPT
========================================================= */

async function sendLocation(
  latitude,
  longitude,
  accuracy
) {

  const data = {

    shareId: SHARE_ID,

    latitude: latitude,

    longitude: longitude,

    accuracy: accuracy,

    timestamp:
      new Date().toISOString()

  };


  try {

    const response =
      await fetch(

        BACKEND_URL,

        {

          method: "POST",

          headers: {

            "Content-Type":
              "text/plain;charset=utf-8"

          },

          body:
            JSON.stringify(data)

        }

      );


    const result =
      await response.json();


    if (result.ok) {

      setStatus(
        "🟢 LIVE LOCATION SHARING ACTIVE"
      );

    }

    else {

      setStatus(
        "⚠️ " +
        (result.error || "Server error")
      );

    }

  }

  catch(error) {

    setStatus(
      "⚠️ Server connection error."
    );

    console.error(error);

  }

}


/* =========================================================
   SHOW SHARED LOCATION
========================================================= */

function showLocation(
  latitude,
  longitude,
  accuracy
) {

  document
    .getElementById("info")
    .style.display = "block";


  document
    .getElementById("lat")
    .textContent =
      latitude.toFixed(6);


  document
    .getElementById("lng")
    .textContent =
      longitude.toFixed(6);


  document
    .getElementById("acc")
    .textContent =
      Math.round(accuracy) +
      " meters";


  document
    .getElementById("time")
    .textContent =
      new Date()
      .toLocaleTimeString();

}


/* =========================================================
   SHARE STATUS
========================================================= */

function setStatus(message) {

  const element =
    document.getElementById("status");

  if (element) {

    element.textContent =
      message;

  }

}


/* =========================================================
   LIVE MAP
========================================================= */

let map = null;

let marker = null;

let circle = null;

let firstLocation = true;

let oldLat = null;

let oldLng = null;

let currentLat = null;

let currentLng = null;


/* =========================================================
   INITIALIZE MAP
========================================================= */

function initMap() {

  map =
    L.map("map");


  L.tileLayer(

    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",

    {

      maxZoom: 19,

      attribution:
        "&copy; OpenStreetMap contributors"

    }

  ).addTo(map);


  map.setView(

    [9.145,40.489],

    5

  );

}


/* =========================================================
   GET LOCATION FROM BACKEND
========================================================= */

async function getLocation() {

  const url =
    BACKEND_URL +
    "?id=" +
    encodeURIComponent(
      SHARE_ID
    );


  try {

    const response =
      await fetch(

        url,

        {

          cache:
            "no-store"

        }

      );


    const data =
      await response.json();


    if (!data.ok) {

      setMapStatus(
        "❌ Server error"
      );

      return;

    }


    if (!data.found) {

      setMapStatus(
        "⏳ Waiting for user location..."
      );

      return;

    }


    updateMap(

      Number(data.latitude),

      Number(data.longitude),

      Number(data.accuracy || 0)

    );


    setMapStatus(
      "🟢 LIVE"
    );

  }

  catch(error) {

    setMapStatus(
      "🔴 Connection error"
    );

    console.error(error);

  }

}


/* =========================================================
   UPDATE MAP MARKER
========================================================= */

function updateMap(
  lat,
  lng,
  accuracy
) {

  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng)
  ) {

    setMapStatus(
      "⚠️ Invalid location data"
    );

    return;

  }


  const position =
    [lat,lng];


  currentLat =
    lat;

  currentLng =
    lng;


  /* Marker */

  if (!marker) {

    marker =
      L.marker(position)
      .addTo(map);


    marker.bindPopup(
      "📍 Current Location"
    );

  }

  else {

    marker.setLatLng(
      position
    );

  }


  /* Accuracy circle */

  if (!circle) {

    circle =
      L.circle(

        position,

        {

          radius:
            accuracy || 0,

          weight: 2,

          fillOpacity: .15

        }

      ).addTo(map);

  }

  else {

    circle.setLatLng(
      position
    );

    circle.setRadius(
      accuracy || 0
    );

  }


  /* First location */

  if (firstLocation) {

    firstLocation =
      false;


    map.flyTo(

      position,

      17,

      {

        duration: 2.5,

        easeLinearity: .25

      }

    );


    setTimeout(

      function() {

        if (marker) {

          marker.openPopup();

        }

      },

      2500

    );

  }


  /* Following movement */

  else {

    if (

      oldLat !== lat ||
      oldLng !== lng

    ) {

      map.panTo(

        position,

        {

          animate: true,

          duration: 1

        }

      );

    }

  }


  oldLat =
    lat;

  oldLng =
    lng;


  document
    .getElementById("accuracy")
    .textContent =
      Math.round(
        accuracy || 0
      ) +
      " meters";


  document
    .getElementById("mapTime")
    .textContent =
      new Date()
      .toLocaleTimeString();

}


/* =========================================================
   MAP STATUS
========================================================= */

function setMapStatus(message) {

  const element =
    document.getElementById(
      "mapStatus"
    );

  if (element) {

    element.textContent =
      message;

  }

}


/* =========================================================
   FOLLOW USER
========================================================= */

function centerOnUser() {

  if (

    map &&
    currentLat !== null &&
    currentLng !== null

  ) {

    map.flyTo(

      [
        currentLat,
        currentLng
      ],

      18,

      {

        duration: 1.5

      }

    );

  }

}


/* =========================================================
   START MAP
========================================================= */

if (mapMode) {

  initMap();

  getLocation();

  setInterval(

    getLocation,

    3000

  );

}

</script>

</body>
</html>
