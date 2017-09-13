import React from 'react'
import Moment from 'moment'

export default class CurrentTime extends React.Component {
  constructor(props) {
    super(props);
    this.state = { currentTimeString: this.formattedTime() };
  }
  tick() {
    this.setState({ currentTimeString: this.formattedTime() });
  }
  componentDidMount() {
    setInterval(this.tick.bind(this), 1000);
  }
  formattedTime() {
    const timeFormat = "dddd, MMM Do, YYYY - h:mm:ss A";
    return Moment().format(timeFormat);
  }
  render() {
    return(
      <p className="navbar-text">
        {this.state.currentTimeString}
      </p>
      )
  }
}
