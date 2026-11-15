import{S as u,i as f,n as p,s as _,j as h,E as b,g as i,c as g,k as v,l as $,a as l,X as x,G as d}from"../chunks/index.5ec26865.js";import{f as m,g as y}from"../chunks/format-page-title.f7c88302.js";import{j as E,m as P,p as j,t as H}from"../chunks/store.67b455b4.js";/**
 * @license BSD-3-Clause
 * Copyright (c) 2023, ッツ Reader Authors
 * All rights reserved.
 */function I(n,e){const t=e.subscribe();return{destroy:()=>t.unsubscribe()}}function N(n){let e,t,s,r,c;return document.title=e=m("Home"),{c(){t=_(),s=h("div")},l(a){b("svelte-1o30anf",document.head).forEach(i),t=g(a),s=v(a,"DIV",{}),$(s).forEach(i)},m(a,o){l(a,t,o),l(a,s,o),r||(c=x(I.call(null,s,n[0])),r=!0)},p(a,[o]){o&0&&e!==(e=m("Home"))&&(document.title=e)},i:d,o:d,d(a){a&&i(t),a&&i(s),r=!1,c()}}}function S(n){return[E.lastItem$.pipe(P(t=>t?`${j}/b?id=${t.dataId}`:"manage"),H(y))]}class D extends u{constructor(e){super(),f(this,e,S,N,p,{})}}export{D as default};
