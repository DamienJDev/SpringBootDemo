package com.example.springboot;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.jar.Attributes;
import java.util.jar.Manifest;

@RestController
@RequestMapping("/system/healthcheck")
public class HealthCheck {
    private static final String VERSION = "version";
    private static final String STATUS = "status";

    @Autowired
    private Environment env;

    @GetMapping("/ping")
    public String ping() {
        return "demo server ok";
    }

    private void loadBuildInfo(Map<String, String> buildInfo) {
        try {
//            URL url = null;
//            System.out.println("------- checking for url");
//            for (Enumeration<URL> e = HealthCheck.class.getClassLoader().getResources("META-INF/MANIFEST.MF"); e.hasMoreElements(); ) {
            URL url = HealthCheck.class.getClassLoader().getResource("META-INF/MANIFEST.MF");
//                URL u = e.nextElement();
//                System.out.println("-------u: " + u);
//                if (!u.toString().startsWith("jar:")) {
//                    url = u;
//                    break;
//                }
//            }
            if (url == null) {
                buildInfo.put(STATUS, "no manifest found");
            } else {
//                InputStream is = new URL(url.toString() + "/MANIFEST.MF").openStream();
                InputStream is = new URL(url.toString()).openStream();
                Manifest manifest = new Manifest(is);
                Attributes attributes = manifest.getMainAttributes();

                buildInfo.put("build version", attributes.getValue("Build-Version"));
                buildInfo.put("build time", attributes.getValue("Build-Time"));
                buildInfo.put("branch", attributes.getValue("Git-Branch"));
                buildInfo.put("commit", attributes.getValue("Git-Commit"));
                buildInfo.put("repo", attributes.getValue("Git-Repo"));
                buildInfo.put(STATUS, "ok");
            }
        } catch (IOException ex) {
            buildInfo.put(STATUS, "error getting manifest info " + ex.getMessage());
        }
    }

    @GetMapping("/tdv")
    public Map<String, Object> tdv() {
        System.out.println("calling tdv");
        Map<String, Object> map = new LinkedHashMap<>();
//        map.put("name", env.getProperty("name"));
//        map.put("fullName", env.getProperty("fullName"));
//        map.put(VERSION, env.getProperty(VERSION));
//        map.put("env", env.getProperty("env"));
        Map<String, String> jdk = new LinkedHashMap<>();
        map.put("jdk", jdk);
        jdk.put("name", System.getProperty("java.vm.name"));
        jdk.put(VERSION, System.getProperty("java.version"));
        Map<String, String> buildInfo = new LinkedHashMap<>();
        map.put("build info", buildInfo);
        loadBuildInfo(buildInfo);
        Map<String, Object> db = new LinkedHashMap<>();
//        map.put("database", db);
//        db.put("url", env.getProperty("spring.datasource.url"));

        try {
            //do db checks and add version etc info here...
            db.put(STATUS, "ok");
        } catch (Exception ex) {
            db.put(STATUS, "error " + ex.getMessage());
        }

//        Map<String, String> releaseInfo = new LinkedHashMap<>();
//        releaseInfo.put("release package", env.getProperty("release.package"));
//        releaseInfo.put("release date", env.getProperty("release.date"));
//        releaseInfo.put("release name", env.getProperty("release.name"));
//        releaseInfo.put("release build", env.getProperty("release.build"));
//        map.put("release info", releaseInfo);
        return map;
    }
}
