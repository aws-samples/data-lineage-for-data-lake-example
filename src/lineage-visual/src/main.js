import Vue from 'vue'
import App from './App.vue'
import router from './router'
import axios from "axios";


Vue.config.productionTip = false
axios.defaults.baseURL = "https://24lx7m1g62.execute-api.eu-west-1.amazonaws.com/dev";

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')
