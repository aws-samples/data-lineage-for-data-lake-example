<template>
  <div>
    <div style="text-align:left;">
      <h3>Job Runs</h3>
        <ul>
          <li v-for="jobRun in jobRuns" :key="jobRun.id">
            {{ jobRun.id }}
          </li>
        </ul>
    </div>
    <div style="text-align:left;">
      <h3>Execution Plans</h3>
        <ul>
          <li v-for="executionPlan in executionPlans">
            <a
              v-bind:href="'/dag/' + executionPlan.id">
              {{ executionPlan.id }}
            </a>
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
  name: 'Job',
  components: {
    Network
  },
  data() {
    return {
      graphData: null,
      jobRuns: [],
      executionPlans: [],
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
    axios.get(`/job/${this.$route.params.id}`, {})
      .then((response) => {
        var payload = response.data
        console.log("payload", payload);
        this.jobRuns = payload.job_runs;
        this.executionPlans = payload.execution_plans;

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
            color: "#BBDED6",
            label: `[TABLE] ${table.database}.${table.name}`,
            shape: "box", 
            margin: 20,
            data: table,
        } })
        var nodesData = jobs.concat(tables)
        var edgesData = payload["edges"].map(edge =>{
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