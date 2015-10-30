var BiMap;

BiMap = (function() {
  BiMap.prototype.klength = 0;

  BiMap.prototype.vlength = 0;

  BiMap.prototype.kindex = 0;

  BiMap.prototype.throwOnError = false;

  function BiMap(A) {
    var k, v;
    this.kv = {};
    this.vk = {};
    if (A != null) {
      for (k in A) {
        v = A[k];
        this.push(k, v);
      }
    }
  }

  BiMap.prototype.push = function(k, v) {
    return this.insert(k, v, "push");
  };

  BiMap.prototype.appendKey = function(k, v) {
    return this.insert(k, v, "appendKey");
  };

  BiMap.prototype.appendVal = function(k, v) {
    return this.insert(k, v, "appendVal");
  };

  BiMap.prototype.set = function(k, v) {
    return this.insert(k, v, "set");
  };

  BiMap.prototype.type = function(a) {
    var t;
    t = typeof a;
    if (t === "number" && a !== a) {
      return "NaN";
    }
    if (t !== "object") {
      return t;
    }
    t = toString.call(a);
    if (t === "[object Object]") {
      return "object";
    }
    if (t === "[object Array]") {
      return "array";
    }
    if (t === "[object Boolean]") {
      return "boolean";
    }
    if (t === "[object Null]") {
      return "null";
    }
  };

  BiMap.prototype._assign = function(k, v, type, reverse) {
    var dir, i, rdir, _i, _len;
    if (type == null) {
      type = "push";
    }
    if (reverse == null) {
      reverse = false;
    }
    if (k > this.kindex) {
      this.kindex++;
    }
    dir = reverse ? "vk" : "kv";
    rdir = dir === "vk" ? "kv" : "vk";
    if (type === "push") {
      if (!((this[dir][k] != null) || this[rdir][void 0] === k || this[rdir][null] === k)) {
        this[dir][k] = v;
        return true;
      } else {
        return this.error("" + dir + " mapping for " + k + " already exists");
      }
    } else if (type === "appendVal") {
      if (reverse) {
        if (this.vk[k] != null) {
          if ("array" !== this.type(this.vk[k])) {
            this.vk[k] = [this.vk[k]];
          }
          this.vk[k][this.type(v) === "array" ? "concat" : "push"](v);
        } else {
          this.vk[k] = v;
        }
        return true;
      }
      if (this.kv[k] == null) {
        this.kv[k] = [];
      } else if ("array" !== this.type(this.kv[k])) {
        this.kv[k] = [this.kv[k]];
      }
      this.kv[k][this.type(v) === "array" ? "concat" : "push"](v);
      if ("array" === this.type(v)) {
        for (_i = 0, _len = v.length; _i < _len; _i++) {
          i = v[_i];
          this.kv[k].push(i);
        }
      }
      return true;
    } else if (type === "set") {
      this[dir][k] = v;
      return true;
    }
  };

  BiMap.prototype.insert = function(k, v, type) {
    var ktype, vtype;
    if (type == null) {
      type = "push";
    }
    if (k == null) {
      return this.error("At least one argument required by insert()");
    }
    ktype = this.type(k);
    if (v == null) {
      if ("array" === this.type(k)) {
        return (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = k.length; _i < _len; _i++) {
            v = k[_i];
            _results.push(this.insert(++this.kindex - 1, v, type));
          }
          return _results;
        }).call(this);
      } else if ("object" === this.type(k)) {
        return this.traverse(k, (function(v, path) {
          return this.insert(path, v, type);
        }).bind(this));
      } else {
        return this.insert(++this.kindex - 1, k, type);
      }
    } else if (this.type(k) === "number" && k > this.kindex) {
      this.kindex = k + 1;
    }
    vtype = this.type(v);
    if (vtype === "object") {
      return this.traverse(v, (function(v, path) {
        return this.insert("" + k + "." + path, v, type);
      }).bind(this));
    } else if (vtype === "array") {
      if (ktype === "array") {
        this.insertArray(v, k, type, true);
      }
      return this.insertArray(k, v, type);
    } else if (ktype === "array") {
      return this.insertArray(v, k, type, true);
    } else {
      if (this._assign(k, v, type)) {
        return this._assign(v, k, type, true);
      }
      return false;
    }
  };

  BiMap.prototype.insertArray = function(k, array, type, reverse) {
    var i, r, _i, _len;
    if (type == null) {
      type = "push";
    }
    if (reverse == null) {
      reverse = false;
    }
    if (this.type(k) !== "array") {
      this._assign(k, array, type, reverse);
    }
    r = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        i = array[_i];
        _results.push(this._assign(i, k, type, !reverse));
      }
      return _results;
    }).call(this);
    for (_i = 0, _len = r.length; _i < _len; _i++) {
      i = r[_i];
      if (!i) {
        return false;
      }
    }
    return true;
  };

  BiMap.prototype.traverse = function(obj, cb) {
    var k, npath, path, v, _results;
    path = arguments[2] || "";
    if ("object" === this.type(obj)) {
      _results = [];
      for (k in obj) {
        v = obj[k];
        npath = path;
        if (path.length > 0) {
          npath += ".";
        }
        npath += k;
        _results.push(this.traverse(v, cb, npath));
      }
      return _results;
    } else {
      return cb(obj, path);
    }
  };

  BiMap.prototype.setNull = function(k, v) {
    this.kv[k] = v;
    this.vk[v] = k;
    this.kindex++;
    return true;
  };

  BiMap.prototype.error = function(e) {
    if (this.throwOnError) {
      throw new Error(e);
    }
    return false;
  };

  BiMap.prototype.removeKey = function(k) {
    var i, index, _i, _len, _ref;
    if (this.type(this.kv[k]) === "array") {
      _ref = this.kv[k];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        if (this.type(this.vk[i]) === "array") {
          index = this.vk[i].indexOf(k);
          if (index !== -1) {
            this.vk[i].splice(index);
          }
        } else {
          if (this.vk[i] === k) {
            delete this.vk[i];
          }
        }
      }
    } else {
      delete this.vk[this.kv[k]];
    }
    return delete this.kv[k];
  };

  BiMap.prototype.removeVal = function(v) {
    var i, index, _i, _len, _ref;
    if (this.type(this.vk[v]) === "array") {
      _ref = this.vk[v];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        if (this.type(this.kv[i]) === "array") {
          index = this.kv[i].indexOf(v);
          if (index !== -1) {
            this.kv[i].splice(index);
          }
        } else {
          if (this.kv[i] === v) {
            delete this.kv[i];
          }
        }
      }
    } else {
      delete this.kv[this.vk[v]];
    }
    return delete this.vk[v];
  };

  BiMap.prototype.key = function(k) {
    return this.kv[k];
  };

  BiMap.prototype.val = function(v) {
    return this.vk[v];
  };

  return BiMap;

})();

(typeof module === "undefined" || module === null) || (module.exports = BiMap);
