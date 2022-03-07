<template>
  <div>
    <div style="text-align:left;">
        <h3>Jobs</h3>
          <ul>
            <li v-for="job in jobs" :key="job.name">
              <a :href="'/job/' + job.name">{{ job.name }}</a>
            </li>
          </ul>
    </div>
    <Network v-bind:graphData="graphData" v-bind:graphOptions="graphOptions"/>
  </div>
</template>

<script>
import Network from '@/components/Network.vue'
import axios from "axios";

export default {
  name: 'Jobs',
  components: {
    Network
  },
  data() {
    return {
      graphData: null,
      jobs: [],
      graphOptions: {
          interaction: { hover: true },
          layout: {
              hierarchical: {
                  direction: "LR",
                  sortMethod: "directed",
                  levelSeparation: 300,
              }
          },
      },
    }
  },
  mounted() {
    axios.get('/jobs', {})
      .then((response) => {
        var payload = response.data
        console.log("payload", payload);
        this.jobs = payload.jobs;
        var jobs = payload.jobs.map(job => {return {
            id: job[1],
            label: `[JOB] ${job.name}`,
            color: "#ffb6b9", 
            shape: "box",
            margin: 20,
            data: job,
        } })
        var tables = payload.tables.map(table => {
            return {
            id: table[1],
            label: `[TABLE] ${table.database}.${table.name}`,
            color: "#BBDED6",
            shape: "box",
            margin: 20,
            data: table,
          }
        })
        var nodesData = jobs.concat(tables)
        var edgesData = payload["edges"].map(edge =>{
            return {
                from: edge.from,
                to: edge.to,
                arrows: {
                    to: {
                        enabled: true,
                        type: "arrow"
                    }
                },
                color: "#808080",
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
