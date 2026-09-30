package io.github.eslamasabry.opencode_mobile

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.os.SystemClock
import android.system.Os
import android.system.OsConstants
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/** Test APK only: no public app command, host credential export, or fake proof. */
class PhoneEngineAcceptance : Instrumentation() {
    private class Refused(val safeCode: String) : Exception()
    private lateinit var arguments: Bundle
    private lateinit var linux: BuiltinLinux
    private lateinit var privateRoot: File
    private var engineBase = ""
    private var engineToken = ""
    private var serverAuth = ""
    private val profile = "qa_${UUID.randomUUID().toString().replace("-", "")}"
    private val instance = UUID.randomUUID().toString()
    private val heartbeatRunning = AtomicBoolean(false)
    private var heartbeatThread: Thread? = null
    private var activity: Activity? = null
    private var engineStarted = false
    private var serverStarted = false
    private var currentStep = "engine_start_proof"
    private var deadline = 0L
    private val criterion = "The repository root contains PHONE_ENGINE_QA.txt with exactly phone-engine-live-acceptance followed by a newline, committed on the task branch; no other tracked file is changed."
    private val personDirectories = linkedSetOf<String>()

    override fun onCreate(arguments: Bundle?) {
        this.arguments = arguments ?: Bundle()
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        var passed = false
        try {
            execute()
            passed = true
        } catch (failure: Refused) {
            emit("FAIL", currentStep, failure.safeCode)
        } catch (failure: PhoneEngineNative.Failure) {
            emit("FAIL", currentStep, failure.code)
        } catch (failure: IllegalStateException) {
            val allowed = setOf("preview_required", "idle_runtime_required", "idle_terminals_required",
                "ubuntu_not_initialized", "git_not_initialized", "positive_write_failed", "positive_git_failed",
                "diagnostic_controls_missing", "diagnostic_complete_inconsistent", "idle_processes_required",
                "fixture_service_not_running", "fixture_service_not_stopped", "unsupported_kernel_activated_engine",
                "production_boundary_not_verified", "unsupported_failure_code_invalid", "activation_timeout",
                "unsupported_authority_enabled", "failed_activation_did_not_restore_server",
                "fixture_service_uptime_missing", "identical_server_start_rotated_process",
                "intentional_stop_was_resurrected", "kernel_probe_timeout", "kernel_probe_signalled_or_invalid")
            emit("FAIL", currentStep, failure.message?.takeIf { it in allowed } ?: "acceptance_failed")
        } catch (_: Exception) {
            // Never forward exception text, model output, server output or auth.
            emit("FAIL", currentStep, "acceptance_failed")
        } finally {
            heartbeatRunning.set(false)
            heartbeatThread?.interrupt()
            heartbeatThread?.join(1200)
            if (::linux.isInitialized) {
                if (serverStarted) try { linux.stopServer() } catch (_: Exception) { }
                if (engineStarted) try { linux.stopPhoneEngine(profile) } catch (_: Exception) { }
            }
            activity?.let { try { runOnMainSync { it.finish() } } catch (_: Exception) { } }
            finish(if (passed) Activity.RESULT_OK else Activity.RESULT_CANCELED,
                Bundle().apply { putString("phoneEngineResult", if (passed) "PASS" else "FAIL") })
        }
    }

    private fun execute() {
        requireSafe(targetContext.packageName == "io.github.eslamasabry.opencode_mobile.preview", "preview_required")
        requireSafe(arguments.getString("isolatedQa") == "true", "isolated_qa_required")
        if (arguments.getString("boundaryRegressions") == "true") {
            currentStep = "device_boundary_regressions"
            activity = startActivitySync(Intent(targetContext, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val results = PhoneEngineDeviceBoundaryRegressions.run(targetContext,
                bootstrap = arguments.getString("bootstrap") != "false") { stage ->
                    currentStep = stage
                    emit("START", stage)
                }
            results.forEach { (control, value) ->
                sendStatus(0, Bundle().apply { putString("phoneEngineControl", "$control=$value") })
            }
            emit("PASS", currentStep, "verified")
            return
        }
        if (arguments.getString("nativeRegressions") == "true") {
            currentStep = "native_regressions"
            PhoneEngineNativeRegressions.run(targetContext)
            emit("PASS", currentStep, "verified")
            return
        }
        if (arguments.getString("reproofRegression") == "true") {
            currentStep = "running_generation_reproof"
            PhoneEngineNativeRegressions.reproofRunningGeneration(targetContext)
            emit("PASS", currentStep, "verified")
            return
        }
        requireSafe(arguments.getString("allowModelSpend") == "true", "model_spend_required")
        requireSafe(arguments.getString("server") == "http://127.0.0.1:4097", "in_app_server_required")
        val model = arguments.getString("model") ?: throw Refused("model_required")
        requireSafe(model.length <= 256 && Regex("^[A-Za-z0-9_.:-]+/[A-Za-z0-9_./:-]+$").matches(model), "model_invalid")
        val timeout = arguments.getString("timeoutSeconds")?.toLongOrNull() ?: 900L
        requireSafe(timeout in 30..3600, "timeout_invalid")
        deadline = SystemClock.elapsedRealtime() + timeout * 1000L
        assertPackagedAbiParser()

        // Instrumentation deliberately runs only in disposable preview storage.
        // Foreground the real activity before invoking its native FGS controls.
        activity = startActivitySync(Intent(targetContext, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        linux = BuiltinLinux.get(targetContext)
        requireSafe(File(linux.home, "ubuntu.ready").isFile, "ubuntu_not_initialized")
        val passwordFile = File(linux.rootfs, "root/.oc-builtin/server.password")
        requireSafe(regularPrivate(passwordFile), "server_auth_unavailable")
        val password = passwordFile.readText()
        requireSafe(password.length in 1..4096, "server_auth_unavailable")
        serverAuth = "Basic " + Base64.encodeToString("opencode:$password".toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
        learnPersonDirectories(File(targetContext.filesDir, "projects"))
        personDirectories.add("/root")
        personDirectories.add("/root/projects")
        if (linux.runningServices().contains(BuiltinLinux.SERVER)) {
            requireSafe(scopedBusySessions(emptySet()).isEmpty(), "person_chat_busy")
        }
        linux.stopServer()
        LocalTerminal.get(targetContext).list().forEach { it.stop() }
        // Never stop services by PID pattern, or silently replace another engine.
        requireSafe(linux.runningServices().isEmpty(), "other_service_running")
        // Compatibility hint only; native startup gets the actual ephemeral
        // address from the child and returns it through private credentials.
        linux.startPhoneEngine(profile, 4098, "AI Team acceptance")
        engineStarted = true
        val auth = linux.phoneEngineCredentials(profile)
        engineBase = auth["baseUrl"] ?: throw Refused("engine_auth_unavailable")
        engineToken = auth["bearerToken"] ?: throw Refused("engine_auth_unavailable")
        privateRoot = File(targetContext.filesDir, "oc.teamEngine.$profile")
        requireSafe(engine("GET", "/v1/health").body.getJSONObject("capabilities").getBoolean("boundary"), "boundary_proof_failed")
        // Same OC1 command/auth contract as BuiltinLinux.serverScript. The
        // optional phone context hint has no bearing on server authentication.
        linux.startServer("""
            set -eu
            mkdir -p /root/projects
            cd /root/projects
            [ -s /root/.oc-builtin/server.password ] || exit 78
            password=${'$'}(cat /root/.oc-builtin/server.password)
            export OPENCODE_SERVER_USERNAME=opencode
            export OPENCODE_SERVER_PASSWORD="${'$'}password"
            export OPENCODE_PASSWORD="${'$'}password"
            unset password
            exec opencode serve --hostname 127.0.0.1 --port 4097
        """.trimIndent(), 4097)
        serverStarted = true
        waitUntil("protocol_not_verified") {
            requireSafe(linux.serverRunning, "in_app_server_exited")
            val health = engine("GET", "/v1/health").body
            val capabilities = health.getJSONObject("capabilities")
            capabilities.optBoolean("boundary") && capabilities.optBoolean("execution") && capabilities.optBoolean("oc1Verified")
        }
        emit("PASS", currentStep)

        currentStep = "scratch_repo"
        val repoId = "repo_${UUID.randomUUID().toString().replace("-", "")}"
        val scratch = "phone_engine_qa_${UUID.randomUUID().toString().replace("-", "")}"
        val guest = "/root/projects/$scratch"
        val host = File(targetContext.filesDir, "projects/$scratch")
        requireSafe(!host.exists(), "scratch_exists")
        val result = linux.run("""
            set -eu
            umask 077
            mkdir '$guest'
            cd '$guest'
            git init -q -b main
            git config user.name 'Phone engine acceptance'
            git config user.email 'phone-engine-qa@localhost.invalid'
            printf 'Phone engine live acceptance seed\n' > README.md
            git add README.md
            git commit -q -m 'Acceptance seed'
        """.trimIndent(), 30)
        requireSafe(result.exitCode == 0, "scratch_git_failed")
        val seed = readRef(File(host, ".git"), "main")
        personDirectories.add(guest)
        requireSafe(personDirectories.contains(guest), "directory_scope_unknown")
        heartbeat() // Fresh authoritative status before any approved lane.
        heartbeatRunning.set(true)
        heartbeatThread = Thread({
            while (heartbeatRunning.get()) {
                try { Thread.sleep(10_000); if (heartbeatRunning.get()) heartbeat() }
                catch (_: InterruptedException) { break }
                catch (_: Exception) { /* Expiry/unknown pauses admission. */ }
            }
        }, "phone-engine-acceptance-heartbeat").apply { start() }
        for (role in listOf("planner", "worker", "checker")) {
            val instructions = when (role) {
                "planner" -> "Return JSON only. Propose exactly ONE phase id phase_qa and ONE task id task_qa. phaseId phase_qa; roleId worker; repoId $repoId; serverId phone; dependsOn []. Copy this one criterion exactly: $criterion. The phase title is Acceptance and milestoneId milestone_qa. Return spec as an object. Do not modify files."
                "checker" -> "Check the exact committed file contents and git diff against all criteria. Return JSON only, findings [] when all criteria pass and one criterionResults item per criterion with the exact criterion string and status met/unmet. Do not change files."
                else -> "Implement only the approved criterion, then git add and git commit to your existing task branch. Use git -c user.name='Phone engine worker' -c user.email='phone-engine-worker@localhost.invalid' commit when local identity is absent. Do not modify main or dev. Do not access files outside this clone."
            }
            command(JSONObject().put("action", "saveRole").put("role", JSONObject()
                .put("id", role).put("name", role).put("instructions", instructions)
                .put("model", model).put("fallbackModel", "").put("readOnly", role != "worker")))
        }
        val spec = JSONObject().put("goal", "Create and commit PHONE_ENGINE_QA.txt containing exactly phone-engine-live-acceptance and a newline")
            .put("constraints", "Exactly one task, one repository, one phase. No other tracked file changes.")
            .put("outOfScope", "All existing projects and any network or provider configuration.")
            .put("milestones", JSONArray().put(JSONObject().put("id", "milestone_qa").put("title", "Acceptance")
                .put("criteria", JSONArray().put(criterion))))
        val settings = JSONObject().put("mode", "single").put("maxLanes", 1).put("chargingOnly", false)
            .put("reviewLevel", "milestones").put("maxFixRounds", 0)
            .put("budget", JSONObject().put("chosen", true).put("unlimited", true))
        val created = command(JSONObject().put("action", "createProject").put("name", "Phone engine live acceptance")
            .put("settings", settings).put("spec", spec).put("repos", JSONArray().put(JSONObject()
                .put("id", repoId).put("name", "Acceptance scratch").put("serverId", "phone").put("path", guest))))
        val projectId = created.getString("projectId")
        val canonical = File(privateRoot, "repos/repos/$repoId.git")
        requireSafe(readRef(canonical, "main") == seed && readRef(canonical, "dev") == seed, "scratch_import_mismatch")
        emit("PASS", currentStep)

        currentStep = "approved_plan"
        commandFor(projectId, "approveSpec", JSONObject().put("confirmed", true))
        waitUntil("planner_not_completed") { project(projectId).optString("status") == "needsPlanApproval" }
        val proposed = project(projectId)
        val tasks = proposed.getJSONArray("tasks")
        val phases = proposed.getJSONArray("phases")
        requireSafe(tasks.length() == 1 && phases.length() == 1, "plan_not_single_task")
        val task = tasks.getJSONObject(0)
        requireSafe(task.optString("id") == "task_qa" && task.optString("repoId") == repoId &&
            task.optString("roleId") == "worker" && task.optString("phaseId") == "phase_qa" &&
            task.optString("serverId") == "phone" && task.getJSONArray("dependsOn").length() == 0 &&
            task.getJSONArray("criteria").length() == 1 && task.getJSONArray("criteria").getString(0) == criterion &&
            phases.getJSONObject(0).optString("id") == "phase_qa", "plan_scope_mismatch")
        commandFor(projectId, "approvePlan", JSONObject().put("confirmed", true))
        emit("PASS", currentStep)

        currentStep = "checked_dev_merge"
        waitUntil("task_not_merged") { project(projectId).getJSONArray("tasks").getJSONObject(0).optString("status") == "merged" }
        val checked = project(projectId)
        val checkedTask = checked.getJSONArray("tasks").getJSONObject(0)
        requireSafe(checkedTask.getJSONArray("findings").length() == 0 &&
            checkedTask.getJSONArray("criterionResults").length() == 1 &&
            checkedTask.getJSONArray("criterionResults").getJSONObject(0).optString("criterion") == criterion &&
            checkedTask.getJSONArray("criterionResults").getJSONObject(0).optString("status") == "met", "checker_not_passed")
        val repo = checked.getJSONArray("repos").getJSONObject(0)
        val dev = repo.getString("devCommit")
        requireSafe(dev != seed && readRef(canonical, "dev") == dev && readRef(canonical, "main") == seed, "dev_merge_mismatch")
        val taskDirectory = File(linux.rootfs, "root/aiteam/work/$profile/$repoId/task_qa")
        val checkGit = linux.run("""
            set -eu
            cd '/root/aiteam/work/$profile/$repoId/task_qa'
            test "${'$'}(git show '$dev:PHONE_ENGINE_QA.txt' | od -An -tx1 | tr -d ' \n')" = '70686f6e652d656e67696e652d6c6976652d616363657074616e63650a'
            test "${'$'}(git diff --name-only '$seed' '$dev')" = 'PHONE_ENGINE_QA.txt'
        """.trimIndent(), 30)
        requireSafe(taskDirectory.isDirectory && checkGit.exitCode == 0, "committed_criterion_mismatch")
        requireSafe(checked.getJSONArray("receipts").objects().any { it.optString("kind") == "merge" && it.optString("after") == dev }, "merge_receipt_missing")
        emit("PASS", currentStep)

        currentStep = "unconfirmed_promotion_refused"
        val refused = engine("POST", "/v1/commands", promotion(projectId, repoId, dev, seed, false, "refuse_${UUID.randomUUID()}"))
        requireSafe(refused.status == 409 && refused.body.optString("code") == "confirmationRequired" &&
            readRef(canonical, "main") == seed && project(projectId).getJSONArray("repos").getJSONObject(0).optString("mainCommit") == seed,
            "unconfirmed_promotion_allowed")
        emit("PASS", currentStep)

        currentStep = "confirmed_promotion_receipt"
        val requestId = "promote_${UUID.randomUUID()}"
        val promotion = promotion(projectId, repoId, dev, seed, true, requestId)
        val receipt = engine("POST", "/v1/commands", promotion)
        requireSafe(receipt.status == 200 && receipt.body.optBoolean("accepted"), "confirmed_promotion_refused")
        requireSafe(readRef(canonical, "main") == dev && readRef(canonical, "dev") == dev, "promoted_refs_mismatch")
        val durableReceipt = File(privateRoot, "repos/receipts/$requestId.json")
        requireSafe(regularPrivate(durableReceipt), "durable_receipt_missing")
        val stored = JSONObject(durableReceipt.readText())
        requireSafe(stored.optString("state") == "applied" && stored.optBoolean("confirmed") &&
            stored.optString("repoId") == repoId && stored.optString("requestId") == requestId &&
            stored.optString("expectedMain") == seed && stored.optString("expectedDev") == dev, "durable_receipt_mismatch")
        val diskProject = persistedWorkspace().getJSONArray("projects").objects().single { it.optString("id") == projectId }
        requireSafe(diskProject.getJSONArray("receipts").objects().any { it.optString("id") == requestId &&
            it.optString("kind") == "promote" && it.optString("before") == seed && it.optString("after") == dev }, "sqlite_receipt_missing")
        val replay = engine("POST", "/v1/commands", promotion)
        requireSafe(replay.status == 200 && replay.body.optBoolean("accepted") && replay.body.optBoolean("replayed") &&
            readRef(canonical, "main") == dev, "promotion_replay_failed")
        emit("PASS", currentStep)
    }

    private data class Reply(val status: Int, val body: JSONObject)

    private fun request(base: String, auth: String, method: String, path: String, body: JSONObject? = null): Reply {
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 3000
            connection.readTimeout = 5000
            connection.setRequestProperty("Authorization", auth)
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val input = if (status in 200..299) connection.inputStream else connection.errorStream
            val bytes = input?.use {
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (output.size() <= 1_048_576) {
                    val read = it.read(buffer, 0, minOf(buffer.size, 1_048_577 - output.size()))
                    if (read < 0) break
                    output.write(buffer, 0, read)
                }
                output.toByteArray()
            } ?: ByteArray(0)
            requireSafe(bytes.size <= 1_048_576, "response_limit")
            return Reply(status, if (bytes.isEmpty()) JSONObject() else JSONObject(String(bytes, Charsets.UTF_8)))
        } finally { connection.disconnect() }
    }

    private fun engine(method: String, path: String, body: JSONObject? = null): Reply =
        request(engineBase, "Bearer $engineToken", method, path, body)

    private fun command(body: JSONObject): JSONObject {
        if (!body.has("requestId")) body.put("requestId", "request_${UUID.randomUUID()}")
        val reply = engine("POST", "/v1/commands", body)
        requireSafe(reply.status == 200 && reply.body.optBoolean("accepted"), "engine_command_refused")
        return reply.body
    }

    private fun commandFor(projectId: String, action: String, body: JSONObject): JSONObject =
        command(body.put("action", action).put("projectId", projectId)
            .put("expectedRevision", project(projectId).getLong("revision")))

    private fun project(id: String): JSONObject {
        val reply = engine("GET", "/v1/workspace")
        requireSafe(reply.status == 200, "workspace_unavailable")
        return reply.body.getJSONArray("projects").objects().singleOrNull { it.optString("id") == id }
            ?: throw Refused("project_missing")
    }

    private fun promotion(projectId: String, repo: String, dev: String, main: String, confirmed: Boolean, request: String): JSONObject =
        JSONObject().put("action", "promote").put("projectId", projectId).put("targetId", repo)
            .put("expectedRevision", project(projectId).getLong("revision")).put("confirmed", confirmed)
            .put("expectedDevCommit", dev).put("expectedMainCommit", main).put("requestId", request)

    private var heartbeatSequence = 0L
    @Synchronized private fun heartbeat() {
        val busy = linkedSetOf<String>()
        var known = true
        try {
            busy.addAll(scopedBusySessions(teamSessions()))
        } catch (_: Exception) { known = false }
        val response = engine("POST", "/v1/chatBusy", JSONObject().put("until", System.currentTimeMillis() + 25_000L)
            .put("sessionIds", JSONArray(busy.toList())).put("directories", JSONArray(personDirectories.toList()))
            .put("known", known).put("appInstance", instance).put("sequence", ++heartbeatSequence))
        requireSafe(response.status == 200 && response.body.optBoolean("accepted"), "heartbeat_refused")
        requireSafe(known, "chat_status_unknown")
    }

    private fun scopedBusySessions(team: Set<String>): Set<String> {
        val busy = linkedSetOf<String>()
        val started = SystemClock.elapsedRealtime()
        val health = request("http://127.0.0.1:4097", serverAuth, "GET", "/global/health")
        requireSafe(health.status == 200 && health.body.optBoolean("healthy") && health.body.optString("version") == "1.18.32", "server_status_unknown")
        for (directory in personDirectories) {
            val status = request("http://127.0.0.1:4097", serverAuth, "GET",
                "/session/status?directory=" + URLEncoder.encode(directory, "UTF-8"))
            requireSafe(status.status == 200, "server_status_unknown")
            val keys = status.body.keys()
            while (keys.hasNext()) {
                val id = keys.next()
                val value = status.body.getJSONObject(id)
                requireSafe(Regex("^ses[A-Za-z0-9_]{1,125}$").matches(id), "server_status_unknown")
                validateStatus(value)
                when (value.optString("type")) {
                    "idle" -> Unit
                    "busy", "retry" -> if (!team.contains(id)) busy.add(id)
                    else -> throw Refused("server_status_unknown")
                }
            }
            requireSafe(SystemClock.elapsedRealtime() - started <= 10_000L, "server_status_stale")
        }
        return busy
    }

    private fun validateStatus(value: JSONObject) {
        when (value.optString("type")) {
            "idle", "busy" -> requireSafe(value.length() == 1, "server_status_unknown")
            "retry" -> {
                fun unsigned(key: String): Boolean {
                    val number = value.opt(key)
                    return number is Int && number >= 0 || number is Long && number >= 0
                }
                requireSafe(unsigned("attempt") && unsigned("next") && value.opt("message") is String &&
                    value.keys().asSequence().all { it in setOf("type", "attempt", "next", "message", "action") }, "server_status_unknown")
                if (value.has("action")) {
                    val action = value.optJSONObject("action") ?: throw Refused("server_status_unknown")
                    requireSafe(listOf("reason", "provider", "title", "message", "label").all { action.opt(it) is String } &&
                        action.keys().asSequence().all { it in setOf("reason", "provider", "title", "message", "label", "link") } &&
                        (!action.has("link") || action.opt("link") is String), "server_status_unknown")
                }
            }
            else -> throw Refused("server_status_unknown")
        }
    }

    // Header fixtures exercise only the parser. They never replace installed
    // ELF verification, native proof, engine state, or live model execution.
    private fun assertPackagedAbiParser() {
        fun header(machine: Int): ByteArray = ByteArray(64).apply {
            this[0] = 0x7f
            this[1] = 0x45
            this[2] = 0x4c
            this[3] = 0x46
            this[4] = 2
            this[5] = 1
            this[6] = 1
            this[16] = 3
            this[18] = machine.toByte()
            this[19] = (machine shr 8).toByte()
            this[20] = 1
            this[52] = 64
        }
        requireSafe(PhoneEngineNative.packagedAbi(header(183)) == "arm64-v8a" &&
            PhoneEngineNative.packagedAbi(header(62)) == "x86_64", "elf_parser_positive_failed")
        val invalid = mutableListOf(header(183).copyOf(63), header(1))
        for ((offset, wrong) in listOf(0 to 0, 4 to 1, 5 to 2, 6 to 0, 16 to 2, 20 to 0, 21 to 1, 52 to 63)) {
            invalid.add(header(183).apply { this[offset] = wrong.toByte() })
        }
        for (bytes in invalid) {
            var refused = false
            try { PhoneEngineNative.packagedAbi(bytes) }
            catch (_: PhoneEngineNative.Failure) { refused = true }
            requireSafe(refused, "elf_parser_negative_failed")
        }
    }

    private fun learnPersonDirectories(root: File) {
        requireSafe(root.isDirectory && root.parentFile?.canonicalFile == targetContext.filesDir.canonicalFile &&
            !OsConstants.S_ISLNK(Os.lstat(root.absolutePath).st_mode), "directory_scope_unknown")
        fun visit(directory: File, guest: String) {
            requireSafe(personDirectories.size < 240 && directory.canonicalFile.toPath().startsWith(root.canonicalFile.toPath()), "directory_scope_unknown")
            personDirectories.add(guest)
            for (entry in directory.listFiles() ?: throw Refused("directory_scope_unknown")) {
                val stat = Os.lstat(entry.absolutePath)
                requireSafe(!OsConstants.S_ISLNK(stat.st_mode), "directory_scope_unknown")
                if (OsConstants.S_ISDIR(stat.st_mode) && entry.name != ".git" && entry.name != "node_modules") visit(entry, "$guest/${entry.name}")
            }
        }
        visit(root, "/root/projects")
    }

    private fun teamSessions(): Set<String> {
        return database { db ->
            val sessions = linkedSetOf<String>()
            db.rawQuery("SELECT data FROM jobs", null).use { rows ->
                while (rows.moveToNext()) {
                    val ids = JSONObject(rows.getString(0)).getJSONObject("sessionIds")
                    val keys = ids.keys()
                    while (keys.hasNext()) sessions.add(ids.getString(keys.next()))
                }
            }
            sessions
        }
    }

    private fun persistedWorkspace(): JSONObject = database { db ->
        db.rawQuery("SELECT data FROM workspace WHERE id=1", null).use { rows ->
            requireSafe(rows.moveToFirst(), "sqlite_workspace_missing")
            JSONObject(rows.getString(0))
        }
    }

    private fun <T> database(block: (SQLiteDatabase) -> T): T {
        val file = File(privateRoot, "data/state.sqlite3")
        requireSafe(regularPrivate(file), "sqlite_missing")
        return SQLiteDatabase.openDatabase(file.absolutePath, null, SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS)
            .use(block)
    }

    private fun readRef(repo: File, branch: String): String {
        val loose = File(repo, "refs/heads/$branch")
        val ref = if (loose.isFile) {
            requireSafe(regularPrivate(loose), "canonical_ref_invalid")
            loose.readText().trim()
        } else {
            val packed = File(repo, "packed-refs")
            requireSafe(regularPrivate(packed), "canonical_ref_missing")
            packed.readLines().singleOrNull { it.endsWith(" refs/heads/$branch") }?.substringBefore(' ')
                ?: throw Refused("canonical_ref_missing")
        }
        requireSafe(Regex("^[0-9a-f]{40}$").matches(ref), "canonical_ref_invalid")
        return ref
    }

    private fun regularPrivate(file: File): Boolean = try {
        var cursor: File? = file
        var safe = true
        while (cursor != null && cursor != targetContext.filesDir) {
            if (OsConstants.S_ISLNK(Os.lstat(cursor.absolutePath).st_mode)) safe = false
            cursor = cursor.parentFile
        }
        safe && cursor != null && file.canonicalFile.toPath().startsWith(targetContext.filesDir.canonicalFile.toPath()) &&
            OsConstants.S_ISREG(Os.lstat(file.absolutePath).st_mode)
    } catch (_: Exception) { false }

    private fun waitUntil(code: String, predicate: () -> Boolean) {
        while (SystemClock.elapsedRealtime() < deadline) {
            if (predicate()) return
            Thread.sleep(1000)
        }
        throw Refused(code)
    }

    private fun requireSafe(condition: Boolean, code: String) { if (!condition) throw Refused(code) }
    private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
    private fun emit(status: String, step: String, code: String? = null) = sendStatus(0, Bundle().apply {
        putString("phoneEngineStep", "$status $step" + if (code == null) "" else " $code")
    })
}
