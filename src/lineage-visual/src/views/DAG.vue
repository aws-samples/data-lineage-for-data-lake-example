<template>
  <div>
    <Network v-bind:graphData="graphData" v-bind:graphOptions="graphOptions"/>
  </div>
</template>

<script>
import Network from '@/components/Network.vue'
import axios from "axios";


export default {
  name: 'DAG',
  components: {
    Network
  },
  data() {
    return {
      graphData: null,
      graphOptions: {
          interaction: { hover: true },
          layout: {
              hierarchical: {
                  sortMethod: "directed",
                  parentCentralization: false,
              }
            }
      },
    }
  },
  mounted() {
    axios.get(`/dag/${this.$route.params.id}`, {})
      .then((response) => {
        var payload = response.data
            console.log("payload", payload);
            var nodesData = payload.nodes.map(node => {
                var color = "#ffb6b9"
                if (node[4] === "TABLE") {
                  color = "#BBDED6"
                } else if (node[4] === "READ_OP") {
                  color = "#FFB6B9"
                } else if (node[4] === "WRITE_OP") {
                  color = "#FFB6B9"
                } else if (node[4] === "TRANS_OP") {
                  color = "#FAE3D9"
                }

                var res = {
                    id: node[1],
                    label: `[${node[4]}] ${node.name}`,
                    color: color, 
                    shape: "box", 
                    margin: 5,
                    data: node,
                }
                return res;
            })

            var edgesData = payload.edges.map(edge =>{
                return {
                    color: "#808080",
                    from: edge.from,
                    to: edge.to,
                    arrows: {
                        to: {
                            enabled: true,
                            type: "arrow"
                        }
                    }
                }
            })
        this.graphData = {
          nodes: nodesData,
          edges: edgesData,
        }
      })
      .catch(function (error) {
        console.log("error", error);
      })
  }
}
</script>