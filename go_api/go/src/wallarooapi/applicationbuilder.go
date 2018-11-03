package wallarooapi

import "C"

type ApplicationBuilder struct{}

func MakeApplicationBuilder() *ApplicationBuilder {
	return &ApplicationBuilder{}
}

func (ab *ApplicationBuilder) ToJson() string {
	return `
{
    "Class": "Application",
    "Name": "word count",
    "Pipelines": [
        {
            "Class": "Pipeline",
            "Name": "word count",
            "Source" : {
                "Class": "TCPSource",
                "Host": "127.0.0.1",
                "Port": "7010",
                "DecoderId": 1
            },
            "Partitions": [
                {
                    "Class": "PartitionU64",
                    "PartitionFunctionId": 6,
                    "PartitionListId": 7,
                    "PartitionId": 1
                }
            ],
            "Components": [
                {
                    "Class": "TCPFramedSourceHandler",
                    "ComponentId": 1
                },
                {
                    "Class": "ComputationMultiBuilder",
                    "ComponentId": 2
                },
                {
                    "Class": "StateBuilder",
                    "ComponentId": 3
                },
                {
                    "Class": "StateComputation",
                    "ComponentId": 4
                },
                {
                    "Class": "Encoder",
                    "ComponentId": 5
                }
            ],
            "Connections": [
                {
                    "Class": "ToComputation",
                    "StepId": 1,
                    "FromStepId": 0,
                    "ComputationBuilderId": 2
                },
                {
                    "Class": "ToStatePartition",
                    "StepId": 2,
                    "FromStepId": 1,
                    "StateComputationId": 4,
                    "StateBuilderId": 3,
                    "StateName": "word-count",
                    "PartitionId": 1,
                    "MultiWorker": true
                },
                {
                    "Class": "ToSink",
                    "StepId": 3,
                    "FromStepId": 2,
                    "Sink": {
                        "Class": "TCPSink",
                        "EncoderId": 5,
                        "Host": "127.0.0.1",
                        "Port": "7002"
                    }
                }
            ]
        }
    ]
}
`

}
