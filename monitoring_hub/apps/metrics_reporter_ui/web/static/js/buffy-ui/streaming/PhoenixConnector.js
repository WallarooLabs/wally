import Dispatcher from "../../dispatcher/Dispatcher"
import {Socket} from "phoenix"
import PhoenixChannels from "../../stream-data/channels/PhoenixChannels"
import ChannelDispatchConnector from "../../stream-data/ChannelDispatchConnector"

const phoenixSocket = new Socket("/socket", {});
const phoenixChannelHub = new PhoenixChannels({socket: phoenixSocket});
const phoenixConnector = new ChannelDispatchConnector(phoenixChannelHub, Dispatcher);

export default phoenixConnector;
