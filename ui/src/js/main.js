import React from "react";
import { render } from "react-dom";
import { Router } from "react-router";
import Spout from "./stream-data/spouts/Spout.js";
import Dispatcher from "./dispatcher/Dispatcher.js";
import ChannelDispatchConnector from "./stream-data/ChannelDispatchConnector.js";
import StreamDispatchConnector from "./stream-data/StreamDispatchConnector.js";
import PusherChannels from "./stream-data/channels/PusherChannels.js";
import Channels from "./stream-data/channels/Channels.js";
import AppStreamConnections from "./buffy-ui/streaming/AppStreamConnections.js";
import Routes from "./buffy-ui/routes/Routes.js";
import { getChannelSuffix } from "./util/URL.js";

//const pusherChannelHub = new PusherChannels({appKey: "f59998084f5a50a3406f"});
const channelHub = new Channels();

const connector = new ChannelDispatchConnector(channelHub, Dispatcher);
//const connector = new ChannelDispatchConnector(pusherChannelHub, Dispatcher);

const streamConnector = new StreamDispatchConnector(Dispatcher, channelHub);

AppStreamConnections.channelHubToDispatcherWith(connector);

AppStreamConnections.mockStreamToDispatcherWith(streamConnector);



const rootRoute = Routes.getRoot();

render(
    <Router routes={rootRoute} />,
    document.getElementById("main")
);
