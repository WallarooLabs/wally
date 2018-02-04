import {ReduceStore} from "flux/utils";
import Actions from "../actions/Actions";
import Comparators from "../../util/Comparators";
import Dispatcher from "../../dispatcher/Dispatcher";
import { fromJS, List, Map } from "immutable";
import {minutes, toSeconds} from "../../util/Duration";

const emptyThroughputs = List();

class ThroughputsStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map().set("start-to-end", Map())
					 .set("node-ingress-egress", Map())
					 .set("computation", Map())
					 .set("pipeline", Map())
					 .set("start-to-end-by-worker", Map())
					 .set("computation-by-worker", Map())
					 .set("node-ingress-egress-by-pipeline", Map())
					 .set("pipeline-ingestion", Map())
		return state;
	}
	getThroughputs(category, metricsKey) {
		if (this.getState().hasIn([category, metricsKey])) {
			return this.getState().getIn([category, metricsKey]);
		} else {
			return emptyThroughputs;
		}
	}
	filterTotalThroughputData(state, category, metricsKey, nextTotalThroughputMsg) {
		let sortedThroughputsList = fromJS(nextTotalThroughputMsg.data).sort(
			(a,b) => {
				a.get("time") - b.get("time")
			}
		)
		return state.setIn([category, metricsKey], sortedThroughputsList);
	}
	filterInitialTotalThroughputsData(state, category, metricsKey, nextTotalThroughputMsg) {
		let sortedThroughputsList = fromJS(nextTotalThroughputMsg.data).sort(
			(a,b) => {
				a.get("time") - b.get("time")
			}
		)
		return state.setIn([category, metricsKey], sortedThroughputsList);
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_TOTAL_THROUGHPUT.actionType:
				category = "computation";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_STEP_BY_WORKER_TOTAL_THROUGHPUT.actionType:
				category = "computation-by-worker";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_SOURCE_SINK_TOTAL_THROUGHPUT.actionType:
				category = "start-to-end";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_TOTAL_THROUGHPUT.actionType:
				category = "start-to-end-by-worker";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_INGRESS_EGRESS_TOTAL_THROUGHPUT.actionType:
				category = "node-ingress-egress";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_TOTAL_THROUGHPUT.actionType:
				category = "node-ingress-egress-by-pipeline";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_PIPELINE_TOTAL_THROUGHPUT.actionType:
				category = "pipeline";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_PIPELINE_INGESTION_TOTAL_THROUGHPUT.actionType:
				category = "pipeline-ingestion";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_STEP_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "computation";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_STEP_BY_WORKER_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "computation-by-worker";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_SOURCE_SINK_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "start-to-end";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "start-to-end-by-worker";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_INGRESS_EGRESS_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "node-ingress-egress";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "node-ingress-egress-by-pipeline";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_PIPELINE_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "pipeline";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_PIPELINE_INGESTION_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "pipeline-ingestion";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			default:
				return state;
		}
	}
}

const throughputsStore = new ThroughputsStore(Dispatcher);
export default throughputsStore;
