import React from "react"
import AppConfigStore from "../stores/AppConfigStore"
import AppStreamConnections from "../streaming/AppStreamConnections"
import PhoenixConnector from "../streaming/PhoenixConnector"
import GlobalNav from "./GlobalNav"
import GlobalFooter from "./GlobalFooter"
import Applications from "./Applications"

export default class App extends React.Component {
  constructor(props) {
    super(props);
    const appConfigs = AppConfigStore.getAppConfigs();
    this.connectAppConfigChannels(appConfigs);
    this.state = {
      appConfigs: appConfigs
    }
    AppConfigStore.addListener(function() {
      if (!this.isUnmounted) {
        const appConfigs = AppConfigStore.getAppConfigs();
        this.connectAppConfigChannels(appConfigs);
        this.setState({
          appConfigs: appConfigs
        });
      }
    }.bind(this));
  }
  connectAppConfigChannels(appConfigs) {
    AppStreamConnections.appConfigsToDispatcherWith(PhoenixConnector, appConfigs);
  }
  componentDidMount() {
    this.isUnmounted = false;
  }
  componentWillUnmount() {
    this.isUnmounted = true;
  }
  render() {
    const { appConfigs } = this.state;
    return (
      <div>
        <GlobalNav appConfigs={appConfigs} />
        <div className="container">
          {this.props.children || <Applications appConfigs={appConfigs} />}
        </div>
        <GlobalFooter />
      </div>
    )
  };
}
