package com.lifey;

import jakarta.persistence.Embeddable;
import jakarta.persistence.Entity;
import jakarta.persistence.MappedSuperclass;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.boot.MetadataSources;
import org.hibernate.boot.registry.StandardServiceRegistryBuilder;
import org.hibernate.dialect.PostgreSQLDialect;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.core.type.filter.AssignableTypeFilter;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Parses every non-native {@code @Query} in the project with Hibernate, with no
 * database at all: the {@link SessionFactory} is built from the entity classes and
 * the PostgreSQL dialect only (JDBC metadata access off), and {@code createQuery}
 * does the HQL parse and semantic check, which needs no connection.
 *
 * <p>This exists because the Testcontainers tests that would otherwise catch a
 * JPQL typo (an unknown attribute, a bad {@code member of}) need Docker, and a
 * broken query otherwise only surfaces when the application boots. It checks
 * that every query is <em>valid</em>, not that it returns the right rows — a real
 * Postgres is still the only thing that does that.
 */
class JpqlQueryValidationTest {

    private static SessionFactory sessionFactory;
    private static Session session;

    @BeforeAll
    static void bootHibernateWithoutADatabase() {
        StandardServiceRegistryBuilder registry = new StandardServiceRegistryBuilder()
                .applySetting("hibernate.dialect", PostgreSQLDialect.class.getName())
                .applySetting("hibernate.boot.allow_jdbc_metadata_access", "false")
                .applySetting("hibernate.hbm2ddl.auto", "none")
                .applySetting("hibernate.connection.provider_class",
                        "org.hibernate.engine.jdbc.connections.internal.UserSuppliedConnectionProviderImpl");
        MetadataSources sources = new MetadataSources(registry.build());
        for (Class<?> type : scan(Entity.class, MappedSuperclass.class, Embeddable.class)) {
            sources.addAnnotatedClass(type);
        }
        sessionFactory = sources.buildMetadata().buildSessionFactory();
        session = sessionFactory.openSession();
    }

    @AfterAll
    static void close() {
        if (session != null) session.close();
        if (sessionFactory != null) sessionFactory.close();
    }

    @Test
    void everyJpqlQueryInTheProjectParses() {
        List<String> failures = new ArrayList<>();
        int checked = 0;
        for (Class<?> repository : repositories()) {
            for (Method method : repository.getDeclaredMethods()) {
                Query query = method.getAnnotation(Query.class);
                if (query == null || query.nativeQuery() || query.value().isBlank()
                        || query.value().contains("#{")) {
                    continue;
                }
                checked++;
                try {
                    session.createQuery(query.value());
                } catch (RuntimeException e) {
                    failures.add(repository.getSimpleName() + "#" + method.getName() + ": " + e.getMessage());
                }
            }
        }
        assertThat(checked).as("the scan should find the project's @Query methods").isGreaterThan(20);
        assertThat(failures).as("queries Hibernate rejects").isEmpty();
    }

    private static List<Class<?>> repositories() {
        ClassPathScanningCandidateComponentProvider provider = new ClassPathScanningCandidateComponentProvider(false) {
            @Override
            protected boolean isCandidateComponent(org.springframework.beans.factory.annotation.AnnotatedBeanDefinition definition) {
                return definition.getMetadata().isInterface();
            }
        };
        provider.addIncludeFilter(new AssignableTypeFilter(Repository.class));
        return load(provider);
    }

    @SafeVarargs
    private static List<Class<?>> scan(Class<? extends java.lang.annotation.Annotation>... annotations) {
        ClassPathScanningCandidateComponentProvider provider = new ClassPathScanningCandidateComponentProvider(false);
        for (Class<? extends java.lang.annotation.Annotation> annotation : annotations) {
            provider.addIncludeFilter(new AnnotationTypeFilter(annotation));
        }
        return load(provider);
    }

    private static List<Class<?>> load(ClassPathScanningCandidateComponentProvider provider) {
        List<Class<?>> types = new ArrayList<>();
        for (BeanDefinition definition : provider.findCandidateComponents("com.lifey")) {
            try {
                types.add(Class.forName(definition.getBeanClassName()));
            } catch (ClassNotFoundException e) {
                throw new IllegalStateException(e);
            }
        }
        return types;
    }
}
