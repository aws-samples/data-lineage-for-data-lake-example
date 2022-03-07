<template>
  <div class="container">
    <div id="mynetwork" />
    <div id="properties">
      <h3>Properties</h3>
      <pre>{{ selectedNode }}</pre>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Network',
  data: function (){
    return {
      selectedNode: null
    }
  },
  props: {
    graphData: Object,
    graphOptions: Object,
  },
  watch: {
    graphData: function (){
      const vis = require("vis-network");
      const visData = require("vis-data");

      var container = document.getElementById("mynetwork");
      var data = {
          nodes: new visData.DataSet(this.graphData.nodes),
          edges: new visData.DataSet(this.graphData.edges),
      };
      var network = new vis.Network(container, data, this.graphOptions);
      network.on("stabilizationIterationsDone", function () {
          network.setOptions( { physics: false } );
      });
      network.on("click", (params)=> {
        if (params.nodes.length > 0) {
          var nodeData = this.graphData.nodes.filter(node => node.id == params.nodes[0])[0];
          if (nodeData.data.schema) {
            try {
              nodeData.data.schema = JSON.parse(nodeData.data.schema);
            }
            catch(e) {
            }
          }
          if (nodeData.data.details) {
            try {
              nodeData.data.details = JSON.parse(nodeData.data.details);
            }
            catch(e) {
            }
          }
          if (nodeData.data.param) {
            try {
              nodeData.data.param = JSON.parse(nodeData.data.param);
            }
            catch(e) {
            }
          }
          this.selectedNode = JSON.stringify(nodeData, undefined, 2)
        }
      });
    }
  }
}
</script>
<style scoped>
.container {
  display: flex;                  /* establish flex container */
  flex-direction: row;            /* default value; can be omitted */
  flex-wrap: nowrap;              /* default value; can be omitted */
  justify-content: space-between; /* switched from default (flex-start, see below) */
}

#mynetwork {
  width: 80%;
  height: 600px;
  border: 1px solid lightgray;
}

#properties {
  width: 20%;
  margin: 10px 10px;
}

pre {
  text-align: left;
}
</style>
