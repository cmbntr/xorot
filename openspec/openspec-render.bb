#!/usr/bin/env bb

;; OpenSpec render helper
;; ======================
;;
;; Scope
;; - This script renders OpenSpec markdown artifacts into a single markdown file.
;; - It owns discovery, ordering, aggregation, Pandoc normalization, cache output,
;;   and viewer invocation.
;; - Task runner orchestration is intentionally out of scope for this file-level
;;   requirements block.
;;
;; Output/cache
;; - Rendered artifacts are written below openspec/.render-cache/.
;; - All mode renders all changes and all specs into all.md.
;; - Specs/changes with no filters render to all-specs.md and all-changes.md.
;; - Filtered or picked renders use openspec-XXXXXXXXXX.md, where XXXXXXXXXX is
;;   a stable hash of the render inputs.
;; - Pandoc input may be staged as a temporary .raw.md file, but raw intermediates
;;   must be removed after each run.
;; - The final artifact path is printed before viewer invocation.
;; - Generated markdown must not include generator-status boilerplate comments.
;;
;; Viewer behavior
;; - Rendering creates/updates the cache artifact first, then invokes a viewer.
;; - Viewer fallback order is: $MD_VIEWER, marker, glow, $PAGER, less.
;; - $MD_VIEWER and $PAGER are shell command fragments, so arguments such as
;;   MD_VIEWER="glow --tui" are supported; the rendered file path is shell-quoted
;;   and appended.
;;
;; Specs rendering
;; - Specs mode with no regex renders all openspec/specs/**/*.md files.
;; - Specs mode with regex arguments renders matching spec files only.
;; - Regex matching considers both the repo-relative path and rendered heading
;;   label.
;; - Expected spec files, */spec.md, are ordered first alphabetically.
;; - Non-expected markdown files under openspec/specs/ are included after expected
;;   spec.md files, alphabetically.
;; - For rendered headings, drop the openspec/specs/ prefix.
;; - If the file name is spec.md, use only the basename of the spec directory.
;; - If the file name is not spec.md, keep the path below openspec/specs/.
;; - Rendered specs are grouped by spec directory.
;; - Each rendered spec section has a Sources sub-TOC linking to the markdown
;;   files included for that spec.
;;
;; Change rendering
;; - Pick mode can render one or more selected spec, active change, or archived
;;   change directories.
;; - All mode renders all active and archived changes together with all specs.
;; - Changes mode with no regex renders all active and archived changes.
;; - Changes mode with regex arguments renders matching changes only.
;; - Regex matching considers both change basename and repo-relative path.
;; - Active matching changes are ordered first, alphabetically.
;; - Archived matching changes are ordered after active changes, reverse
;;   alphabetically; archived names begin with ISO dates, so this is inverse
;;   chronological order.
;; - For each change, read .openspec.yaml to determine the workflow schema name.
;; - Resolve schema definitions through the OpenSpec schema-location command. If
;;   OPENSPEC_TASK is set, invoke task $OPENSPEC_TASK -- schema which --all --json;
;;   otherwise invoke openspec schema which --all --json directly.
;; - Read schema.yaml and follow artifacts[].generates order.
;; - For each generates pattern, collect matching markdown relative to the change
;;   directory; if a glob has multiple hits, sort them alphabetically.
;; - Include non-expected markdown files under the change directory after
;;   schema-generated files, alphabetically. This includes files such as
;;   impl-summary.md.
;; - If schema resolution fails, fallback order is proposal.md, specs/**/*.md,
;;   design.md, tasks.md, then any remaining markdown alphabetically.
;; - For change output, the master TOC lists matched changes, not individual
;;   artifacts.
;; - Each rendered change section has a Sources sub-TOC linking to its artifacts
;;   and additional markdown files.
;; - Change artifact headings strip openspec/changes/ and
;;   openspec/changes/archive/ by rendering paths relative to the change dir.
;;
;; Markdown structure
;; - The master TOC is split into Changes and Specs sections; empty sections are
;;   omitted.
;; - Sources sections contain document-internal links.
;; - Spec sections with only one included spec.md omit their Sources sub-TOC.
;; - Explicit HTML anchors are emitted before linked sections so link behavior does
;;   not depend on renderer-specific heading-id generation.
;; - Pandoc normalizes the combined markdown with -f gfm -t gfm when available;
;;   otherwise normalization is skipped and combined markdown is written directly.

(require '[babashka.fs :as fs]
         '[babashka.process :refer [process sh]]
         '[cheshire.core :as json]
         '[clj-yaml.core :as yaml]
         '[clojure.string :as str]
         '[taoensso.timbre :as timbre])

(def root (fs/cwd))
(def openspec-dir (fs/path root "openspec"))
(def cache-dir (fs/path openspec-dir ".render-cache"))

(defn sha256-prefix [inputs]
  (let [digest (.digest (java.security.MessageDigest/getInstance "SHA-256")
                        (.getBytes (str/join "\u0000" inputs) "UTF-8"))]
    (subs (apply str (map #(format "%02x" (bit-and % 0xff)) digest)) 0 10)))

(defn hashed-artifact-name [inputs]
  (str "openspec-" (sha256-prefix inputs)))

(defn rel [path]
  (str (fs/relativize root path)))

(defn script-path []
  (let [path (str *file*)]
    (if (or (str/blank? path) (= "NO_SOURCE_PATH" path))
      "openspec-render.bb"
      (let [script (fs/path path)
            resolved (if (fs/absolute? script) script (fs/path root script))]
        (rel resolved)))))

(defn usage []
  (let [script (script-path)]
    (binding [*out* *err*]
      (println "Usage:" script "all")
      (println "      " script "specs [regex] [more-regexes...]")
      (println "      " script "changes [regex] [more-regexes...]")
      (println "      " script "pick [query]")
      (println "Generates a single rendered OpenSpec markdown artifact and opens it in a viewer.")
      (println "Pick mode supports multi-select with tab/shift-tab.")
      (println "MD_VIEWER may include args, e.g. MD_VIEWER=\"glow --tui\"."))))

(defn fail [& parts]
  (timbre/error (str/join "" parts))
  (System/exit 1))

(defn command-available? [command]
  (zero? (:exit (sh {:continue true :out :string :err :string}
                    "sh" "-c" (str "command -v " command " >/dev/null 2>&1")))))

(defn sorted-paths [paths]
  (sort-by #(str (fs/normalize %)) paths))

(defn md-file? [path]
  (and (fs/regular-file? path)
       (= "md" (str/lower-case (fs/extension path)))))

(defn glob-paths [base pattern]
  (->> (fs/glob base pattern)
       (filter md-file?)
       sorted-paths))

(defn markdown-files-under [base]
  (distinct (concat (glob-paths base "*.md")
                    (glob-paths base "**/*.md"))))

(defn regexes [patterns]
  (map re-pattern patterns))

(defn matches-any? [regexes texts]
  (or (empty? regexes)
      (some (fn [regex]
              (some #(re-find regex %) texts))
            regexes)))

(declare spec-heading-label)
(declare change-groups-for-dirs spec-groups-for-files)

(defn literal-or-glob [base pattern]
  (let [path (fs/path base pattern)]
    (if (and (not (str/includes? pattern "*")) (fs/regular-file? path))
      [path]
      (glob-paths base pattern))))

(defn path-key [path]
  (str (fs/normalize path)))

(defn append-unexpected-markdown [base expected]
  (let [expected-files (distinct expected)
        expected-set (set (map path-key expected-files))
        unexpected (->> (markdown-files-under base)
                        (remove #(contains? expected-set (path-key %)))
                        sorted-paths)]
    (concat expected-files unexpected)))

(defn specs-root-files [patterns]
  (let [compiled (regexes patterns)
        specs-dir (fs/path openspec-dir "specs")
        expected (glob-paths specs-dir "*/spec.md")]
    (->> (append-unexpected-markdown specs-dir expected)
         (filter #(matches-any? compiled [(rel %) (spec-heading-label %)])))))

(defn spec-dir-files [dir]
  (append-unexpected-markdown dir (literal-or-glob dir "spec.md")))

(defn json-body [text]
  (let [starts (remove nil? [(str/index-of text "[") (str/index-of text "{")])]
    (when-let [start (first (sort starts))]
      (subs text start))))

(defn load-schema-locations []
  (let [openspec-task (System/getenv "OPENSPEC_TASK")
        command (if (str/blank? openspec-task)
                  ["openspec" "schema" "which" "--all" "--json"]
                  ["task" openspec-task "--" "schema" "which" "--all" "--json"])]
    (timbre/info "Loading OpenSpec schema locations" {:command (str/join " " command)})
    (let [result (apply sh {:continue true :out :string :err :string :dir (str root)} command)]
      (when-not (zero? (:exit result))
        (throw (ex-info "OpenSpec schema lookup failed" {:result result})))
      (let [body (or (json-body (:out result))
                     (throw (ex-info "OpenSpec schema lookup did not return JSON" {:stdout (:out result)})))]
        (->> (json/parse-string body true)
             (map (juxt :name identity))
             (into {}))))))

(def schema-locations-cache (delay (load-schema-locations)))

(defn schema-locations []
  @schema-locations-cache)

(defn change-schema-name [change-dir]
  (let [config (fs/path change-dir ".openspec.yaml")]
    (when (fs/regular-file? config)
      (:schema (yaml/parse-string (slurp (str config)))))))

(defn schema-artifact-patterns [schema-dir]
  (let [schema-file (fs/path schema-dir "schema.yaml")]
    (when-not (fs/regular-file? schema-file)
      (throw (ex-info "schema.yaml not found" {:schema-file schema-file})))
    (->> (:artifacts (yaml/parse-string (slurp (str schema-file))))
         (mapcat (fn [artifact]
                   (let [generates (:generates artifact)]
                     (cond
                       (string? generates) [generates]
                       (sequential? generates) generates
                       :else []))))
         (remove str/blank?)
         vec)))

(defn fallback-change-files [change-dir]
  (let [preferred (mapcat #(literal-or-glob change-dir %)
                          ["proposal.md" "specs/**/*.md" "design.md" "tasks.md"])
        preferred-set (set (map #(str (fs/normalize %)) preferred))
        remaining (->> (markdown-files-under change-dir)
                       (remove #(contains? preferred-set (str (fs/normalize %)))))]
    (concat preferred remaining)))

(defn schema-driven-change-files [change-dir]
  (let [schema-name (change-schema-name change-dir)
        _ (when (str/blank? schema-name)
            (throw (ex-info "Change schema not declared" {:change-dir change-dir})))
        locations (schema-locations)
        schema-dir (get-in locations [schema-name :path])
        _ (when (str/blank? schema-dir)
            (throw (ex-info "Change schema not found" {:schema schema-name})))
        patterns (schema-artifact-patterns schema-dir)]
    (mapcat #(literal-or-glob change-dir %) patterns)))

(defn change-files [change-dir]
  (try
    (append-unexpected-markdown change-dir (schema-driven-change-files change-dir))
    (catch Exception ex
      (timbre/info "Using fallback artifact ordering"
                   {:change (rel change-dir)
                    :reason (ex-message ex)})
      (distinct (fallback-change-files change-dir)))))

(defn immediate-dirs [dir]
  (when (fs/directory? dir)
    (->> (fs/list-dir dir)
         (filter fs/directory?)
         sorted-paths)))

(defn archive-dir? [dir]
  (= "archive" (fs/file-name dir)))

(defn candidates []
  (concat
   (immediate-dirs (fs/path openspec-dir "specs"))
   (remove archive-dir?
            (immediate-dirs (fs/path openspec-dir "changes")))
   (immediate-dirs (fs/path openspec-dir "changes" "archive"))))

(defn active-change-dirs []
  (->> (immediate-dirs (fs/path openspec-dir "changes"))
       (remove archive-dir?)
       sorted-paths))

(defn archived-change-dirs []
  (->> (immediate-dirs (fs/path openspec-dir "changes" "archive"))
       sorted-paths
       reverse))

(defn matching-change-dirs [patterns]
  (let [compiled (regexes patterns)
        matches? (fn [dir]
                   (let [name (fs/file-name dir)
                          relative (rel dir)]
                      (matches-any? compiled [name relative])))]
    (->> (concat (active-change-dirs) (archived-change-dirs))
         (filter matches?))))

(defn pick-dirs [query]
  (let [items (map rel (candidates))]
    (when (empty? items)
      (fail "No OpenSpec directories found to render."))
    (let [fzf-args (cond-> ["fzf" "-m" "-1" "-0" "--prompt=Render > " "--header=Select OpenSpec spec/change directories; tab selects multiple"]
                      (not (str/blank? query)) (conj "-q" query))
           proc (process fzf-args {:in (str (str/join "\n" items) "\n")
                                   :out :string
                                   :err :inherit})
           result @proc
           selected (->> (str/split-lines (:out result))
                         (map str/trim)
                         (remove str/blank?)
                         vec)]
      (when-not (zero? (:exit result))
        (System/exit (:exit result)))
      (when (empty? selected)
        (fail "No OpenSpec directory selected."))
      (mapv #(fs/path root %) selected))))

(defn files-for-picked-dir [dir]
  (let [relative (rel dir)]
    (timbre/info "Collecting markdown files" {:selection relative})
    (cond
      (str/starts-with? relative "openspec/specs/") (spec-dir-files dir)
      (str/starts-with? relative "openspec/changes/") (change-files dir)
      :else (fail "Unsupported selection: " relative))))

(defn slug [text]
  (-> text
      (str/replace #"[^A-Za-z0-9._-]+" "-")
      (str/replace #"(^-+|-+$)" "")
      (str/lower-case)))

(defn artifact-path [name]
  (fs/path cache-dir (str (slug name) ".md")))

(defn spec-heading-label [path]
  (let [relative (rel path)
        prefix "openspec/specs/"
        trimmed (if (str/starts-with? relative prefix)
                  (subs relative (count prefix))
                  relative)]
    (if (= "spec.md" (fs/file-name path))
      (fs/file-name (fs/parent path))
      trimmed)))

(defn change-heading-label [change-dir path]
  (str (fs/relativize change-dir path)))

(defn spec-dir-for-file [path]
  (let [relative (rel path)
        prefix "openspec/specs/"]
    (when (str/starts-with? relative prefix)
      (let [parts (str/split (subs relative (count prefix)) #"/")]
        (when-let [spec-name (first parts)]
          (fs/path openspec-dir "specs" spec-name))))))

(defn markdown-link-label [text]
  (-> text
      (str/replace "\\" "\\\\")
      (str/replace "[" "\\[")
      (str/replace "]" "\\]")))

(defn group-source-entry [group idx path]
  (let [label-fn (case (:kind group)
                   :change #(change-heading-label (:dir group) %)
                   :spec spec-heading-label)
        label (label-fn path)
        anchor (str "source-" (:anchor group) "-" (inc idx) "-" (slug label))]
    {:path path :label label :anchor anchor}))

(defn source-line [{:keys [label anchor]}]
  (str "- [" (markdown-link-label label) "](#" anchor ")\n"))

(defn section-markdown
  ([entry]
   (section-markdown 1 entry))
  ([level {:keys [path label anchor]}]
   (let [marks (apply str (repeat level "#"))]
     (str "<a id=\"" anchor "\"></a>\n\n"
          marks " " label "\n\n"
          (slurp (str path))))))

(defn single-spec-md-group? [{:keys [kind files]}]
  (and (= :spec kind)
       (= 1 (count files))
       (= "spec.md" (fs/file-name (first files)))))

(defn group-entry [kind idx dir files]
  (let [label (fs/file-name dir)]
    {:kind kind
     :dir dir
     :label label
     :files (vec files)}))

(defn change-group-entry [idx dir files]
  (group-entry :change idx dir files))

(defn spec-group-entry [idx dir files]
  (group-entry :spec idx dir files))

(defn master-toc-section [title groups]
  (when (seq groups)
    (str "## " title "\n\n"
         (str/join "" (map source-line groups))
         "\n")))

(defn master-toc-markdown [groups]
  (str (master-toc-section "Changes" (filter #(= :change (:kind %)) groups))
       (master-toc-section "Specs" (filter #(= :spec (:kind %)) groups))))

(defn with-group-anchors [groups]
  (let [changes (filter #(= :change (:kind %)) groups)
        specs (filter #(= :spec (:kind %)) groups)
        index-groups (fn [prefix grouped]
                       (map-indexed (fn [idx group]
                                      (assoc group :anchor (str prefix "-" (inc idx) "-" (slug (:label group)))))
                                    grouped))]
    (concat (index-groups "change" changes)
            (index-groups "spec" specs))))

(defn group-header [anchor label]
  (str "<a id=\"" anchor "\"></a>\n\n"
       "# " label "\n\n"))

(defn group-section-markdown [{:keys [label anchor files] :as group}]
  (let [entries (map-indexed #(group-source-entry group %1 %2) files)]
    (if (single-spec-md-group? group)
      (str (group-header anchor label)
           (slurp (str (first files))))
      (str (group-header anchor label)
           "## Sources\n\n"
           (str/join "" (map source-line entries))
           "\n"
           (str/join "\n\n---\n\n"
                     (map #(section-markdown 2 %) entries))))))

(defn combined-markdown [title groups]
  (let [ordered-groups (with-group-anchors groups)]
    (str "# " title "\n\n"
         (master-toc-markdown ordered-groups)
         (str/join "\n\n---\n\n" (map group-section-markdown ordered-groups))
         "\n")))

(defn pandoc-render [raw-path out-path]
  (timbre/info "Normalizing markdown with pandoc" {:input (rel raw-path) :output (rel out-path)})
  (let [result (sh {:continue true :out :string :err :string :dir (str root)}
                   "pandoc" "-f" "gfm" "-t" "gfm" (str raw-path) "-o" (str out-path))]
    (when-not (zero? (:exit result))
      (when-not (str/blank? (:err result))
        (timbre/error (:err result)))
      (when-not (str/blank? (:out result))
        (timbre/error (:out result)))
      (System/exit (:exit result)))))

(defn render-markdown [markdown out-path raw-path]
  (if (command-available? "pandoc")
    (try
      (spit (str raw-path) markdown)
      (pandoc-render raw-path out-path)
      (finally
        (fs/delete-if-exists raw-path)))
    (do
      (timbre/warn "pandoc not found; skipping markdown normalization" {:output (rel out-path)})
      (spit (str out-path) markdown))))

(defn sh-quote [text]
  (str "'" (str/replace text "'" "'\\''") "'"))

(defn run-shell-viewer [command path]
  (timbre/info "Invoking markdown viewer" {:command command :path (rel path)})
  (let [result (sh {:continue true :dir (str root)}
                   "sh" "-c" (str command " " (sh-quote (str path))))]
    (:exit result)))

(defn run-viewer [command path]
  (timbre/info "Invoking markdown viewer" {:command command :path (rel path)})
  (:exit (sh {:continue true :dir (str root)} command (str path))))

(defn invoke-viewer [path]
  (let [md-viewer (System/getenv "MD_VIEWER")
        pager (System/getenv "PAGER")]
    (cond
      (not (str/blank? md-viewer)) (run-shell-viewer md-viewer path)
      (command-available? "marker") (run-viewer "marker" path)
      (command-available? "glow") (run-viewer "glow" path)
      (not (str/blank? pager)) (run-shell-viewer pager path)
      (command-available? "less") (run-viewer "less" path)
      :else (fail "No markdown viewer found. Set MD_VIEWER, e.g. MD_VIEWER=\"glow --tui\", or install marker/glow/less."))))

(defn write-artifact [name title groups]
  (fs/create-dirs cache-dir)
  (let [render-groups (->> groups
                           (map #(update % :files vec))
                           (remove #(empty? (:files %)))
                           vec)
        file-count (reduce + (map #(count (:files %)) render-groups))]
    (when (empty? render-groups)
      (fail "No markdown files found for " title "."))
    (timbre/info "Rendering OpenSpec markdown" {:title title :groups (count render-groups) :files file-count})
    (let [out-path (artifact-path name)
          raw-path (artifact-path (str name ".raw"))]
      (let [markdown (combined-markdown title render-groups)]
        (render-markdown markdown out-path raw-path)
        (timbre/info "Rendered artifact" {:path (rel out-path)})
        (println (str out-path))
        (let [exit-code (invoke-viewer out-path)]
          (when-not (zero? exit-code)
            (System/exit exit-code)))))))

(defn change-dir? [dir]
  (str/starts-with? (rel dir) "openspec/changes/"))

(defn title-for-picked-dir [dir]
  (fs/file-name dir))

(defn title-for-picked-dirs [dirs]
  (if (= 1 (count dirs))
    (title-for-picked-dir (first dirs))
    "OpenSpec Selection"))

(defn artifact-name-for-picked-dirs [dirs]
  (hashed-artifact-name (cons "pick" (map rel dirs))))

(def all-title "OpenSpec")

(def all-artifact-name "all")

(defn all-groups []
  (concat (change-groups-for-dirs (concat (active-change-dirs) (archived-change-dirs)))
          (spec-groups-for-files (specs-root-files []))))

(defn group-for-picked-dir [idx dir]
  (if (change-dir? dir)
    (change-group-entry idx dir (files-for-picked-dir dir))
    (spec-group-entry idx dir (files-for-picked-dir dir))))

(defn groups-for-picked-dirs [dirs]
  (map-indexed group-for-picked-dir dirs))

(defn spec-groups-for-files [files]
  (->> files
       (group-by spec-dir-for-file)
       (remove (comp nil? key))
       (sort-by #(path-key (key %)))
       (map-indexed (fn [idx [dir files]]
                      (spec-group-entry idx dir (sorted-paths files))))))

(defn change-groups-for-dirs [dirs]
  (map-indexed (fn [idx dir]
                 (change-group-entry idx dir (change-files dir)))
               dirs))

(defn changes-title [patterns]
  (if (empty? patterns)
    "OpenSpec Changes"
    (str "OpenSpec Changes: " (str/join " " patterns))))

(defn changes-artifact-name [patterns]
  (if (empty? patterns)
    "all-changes"
    (hashed-artifact-name (cons "changes" patterns))))

(defn specs-title [patterns]
  (if (empty? patterns)
    "OpenSpec Specs"
    (str "OpenSpec Specs: " (str/join " " patterns))))

(defn specs-artifact-name [patterns]
  (if (empty? patterns)
    "all-specs"
    (hashed-artifact-name (cons "specs" patterns))))

(let [[mode & args] *command-line-args*
      query (str/join " " args)]
  (timbre/info "Starting OpenSpec render" {:mode mode :args args})
  (case mode
    "all"
    (write-artifact all-artifact-name
                    all-title
                    (all-groups))

    "specs"
    (write-artifact (specs-artifact-name args)
                    (specs-title args)
                    (spec-groups-for-files (specs-root-files args)))

    "changes"
    (let [dirs (vec (matching-change-dirs args))]
      (when (empty? dirs)
        (fail "No OpenSpec changes matched regexes: " (str/join " " args)))
      (write-artifact (changes-artifact-name args)
                      (changes-title args)
                      (change-groups-for-dirs dirs)))

    "pick"
    (let [dirs (pick-dirs query)]
      (write-artifact (artifact-name-for-picked-dirs dirs)
                      (title-for-picked-dirs dirs)
                      (groups-for-picked-dirs dirs)))

    (do
      (usage)
      (System/exit 2))))
