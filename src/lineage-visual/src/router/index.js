import Vue from 'vue'
import VueRouter from 'vue-router'
import Jobs from '../views/Jobs.vue'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'Jobs',
    component: Jobs
  },
  {
    path: '/job/:id',
    name: 'Job',
    component: () => import(/* webpackChunkName: "about" */ '../views/Job.vue')
  },
  {
    path: '/dag/:id',
    name: 'DAG',
    component: () => import(/* webpackChunkName: "about" */ '../views/DAG.vue')
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
